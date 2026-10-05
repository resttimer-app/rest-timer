import ActivityKit
import AppIntents
import AVFoundation
import WidgetKit

// MARK: - プリセット

/// 繰り返すタイマーの並び。segments は秒。[300, 1500] なら 5分→25分→5分→… を止めるまで繰り返す。
struct RestPreset: Codable, Hashable {
    var segments: [Int]

    /// 表示名。2区間なら「5分↔25分」、それ以外は「5分→10分→25分」
    var label: String {
        let parts = segments.map(RestPreset.format)
        if parts.count == 2 { return parts.joined(separator: "↔") }
        return parts.joined(separator: "→")
    }

    /// 90 → 「1分30秒」、30 → 「30秒」、3600 → 「60分」
    static func format(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        if m == 0 { return "\(s)秒" }
        if s == 0 { return "\(m)分" }
        return "\(m)分\(s)秒"
    }

    /// アプリで一度も保存していないときの中身
    static let defaults: [RestPreset] = [[120, 180], [300, 1500]].map { RestPreset(segments: $0) }
}

/// プリセットの読み込み。アプリの画面（React Native の Settings）が
/// UserDefaults の "restPresetsSec" に JSON（秒の配列の配列。例: [[120,180],[300,600,1500],[],...]）で書く。
/// 読むのはアプリ本体のプロセスだけ。空の行はメニューに出さない。
enum PresetStore {
    static let key = "restPresetsSec"

    static func all() -> [RestPreset] {
        guard let json = UserDefaults.standard.string(forKey: key),
              let lists = try? JSONDecoder().decode([[Int]].self, from: Data(json.utf8))
        else { return RestPreset.defaults }
        let presets = lists
            .map { $0.filter { (10...3600).contains($0) } }
            .filter { !$0.isEmpty }
            .map { RestPreset(segments: Array($0.prefix(5))) }
        return Array(presets.prefix(6))
    }
}

// MARK: - ライブアクティビティ（ロック画面・Dynamic Island）

struct RestAttributes: ActivityAttributes {
    struct Running: Codable, Hashable {
        var label: String
        /// プリセットの区間（秒）と、今どれか（0から）
        var segments: [Int]
        var index: Int
        var segmentSeconds: Int
        var startDate: Date
        var endDate: Date
        /// 何本目の区間か（1から）
        var count: Int
    }

    struct ContentState: Codable, Hashable {
        /// メニューに並べるプリセット（表示用にアプリ本体から渡す）
        var presets: [RestPreset]
        /// nil ならメニュー表示、値があればカウント中
        var running: Running?
        /// メニューの2段階目: どのプリセットの「どこから始めるか」を選んでいるか（1〜6）
        var choosing: Int? = nil
        /// メニュー1段階目のページ（0: 1〜3番、1: 4〜6番）
        var page: Int = 0
    }
}

// MARK: - インテント
// どれも AudioPlaybackIntent + LiveActivityIntent にして、ロック画面のボタンから押されても必ず、アプリ本体をバックグラウンドで起こして実行させる（拡張のプロセスではライブアクティビティを開始できないため）。

/// ロック画面のボタン・ウィジェットから: プリセットのメニューをロック画面に出す（動いているタイマーは止める）
@available(iOS 17.0, *)
struct ShowRestMenuIntent: AudioPlaybackIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "休憩タイマーのメニューを出す"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "ページ（0か1）", default: 0)
    var page: Int

    init() {}

    init(page: Int) {
        self.page = page
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try await RestEngine.shared.showMenu(page: page)
        return .result()
    }
}

/// メニューの1段階目から: プリセットを選ぶ。区間が2つ以上なら「どこから始めるか」を出し、1つならすぐ始める
@available(iOS 17.0, *)
struct ChoosePresetIntent: AudioPlaybackIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "休憩タイマーのプリセットを選ぶ"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "プリセット番号（1〜6）", default: 1)
    var number: Int

    init() {}

    init(number: Int) {
        self.number = number
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try await RestEngine.shared.choose(presetNumber: number)
        return .result()
    }
}

/// メニューのボタンから: 選んだプリセットで、止めるまで繰り返すタイマーを始める
@available(iOS 17.0, *)
struct StartPresetIntent: AudioPlaybackIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "休憩タイマーを開始"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "プリセット番号（1〜6）", default: 1)
    var number: Int

    @Parameter(title: "何番目の区間から始めるか", default: 1)
    var startAt: Int

    init() {}

    init(number: Int, startAt: Int = 1) {
        self.number = number
        self.startAt = startAt
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try await RestEngine.shared.start(presetNumber: number, startAt: startAt)
        return .result()
    }
}

/// 停止ボタンから: タイマーを止めて、ロック画面の表示も消す
@available(iOS 17.0, *)
struct StopRestIntent: AudioPlaybackIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "休憩タイマーを停止"
    static var openAppWhenRun: Bool = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await RestEngine.shared.stop()
        return .result()
    }
}

// MARK: - タイマー本体（アプリ本体のプロセスで動く）

/// 動いている間は無音をループ再生してアプリを起こしておき、区間の終わりごとにビープ音を鳴らす。
/// カテゴリは .playback（マナーモードの影響を受けない）、
/// オプションは .mixWithOthers（流している音楽を止めない・小さくしない）。
@available(iOS 17.0, *)
@MainActor
final class RestEngine {
    static let shared = RestEngine()

    private var keepAlive: AVAudioPlayer?
    private var beep: AVAudioPlayer?
    private var loop: Task<Void, Never>?

    private init() {
        // プロセスが作り直されたかどうかを記録で見分けるため
        RestLog.add("engine 起動")
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init)
            RestLog.add("音の中断: \(type == .began ? "開始" : "終了")")
            if type == .ended {
                Task { @MainActor in RestEngine.shared.resumeKeepAlive() }
            }
        }
    }

    func showMenu(page: Int = 0) async throws {
        stopSound()
        try await setState(RestAttributes.ContentState(presets: PresetStore.all(), running: nil, page: page))
    }

    func choose(presetNumber: Int) async throws {
        let presets = PresetStore.all()
        guard presets.indices.contains(presetNumber - 1) else { throw RestError.noPreset }
        if presets[presetNumber - 1].segments.count == 1 {
            try await start(presetNumber: presetNumber, startAt: 1)
        } else {
            try await setState(RestAttributes.ContentState(presets: presets, running: nil, choosing: presetNumber))
        }
    }

    func start(presetNumber: Int, startAt: Int) async throws {
        let presets = PresetStore.all()
        guard presets.indices.contains(presetNumber - 1) else { throw RestError.noPreset }
        let preset = presets[presetNumber - 1]

        stopSound()
        try startSound()
        RestLog.add("開始: \(preset.label)（\(startAt)番目の区間から）")

        loop = Task { @MainActor [weak self] in
            let first = min(max(startAt - 1, 0), preset.segments.count - 1)
            var index = first
            var start = Date()
            while !Task.isCancelled {
                let current = index % preset.segments.count
                let seconds = preset.segments[current]
                let end = start.addingTimeInterval(TimeInterval(seconds))
                let running = RestAttributes.Running(
                    label: preset.label, segments: preset.segments, index: current,
                    segmentSeconds: seconds,
                    startDate: start, endDate: end, count: index - first + 1
                )
                do {
                    try await self?.setState(RestAttributes.ContentState(presets: presets, running: running))
                    RestLog.add("表示更新: \(RestPreset.format(seconds))（\(index - first + 1)本目）")
                } catch {
                    RestLog.add("表示更新に失敗: \(error)")
                }

                let wait = end.timeIntervalSinceNow
                if wait > 0 {
                    do {
                        try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                    } catch {
                        RestLog.add("待機が中断（停止）")
                        break
                    }
                }
                if Task.isCancelled { break }
                let late = -end.timeIntervalSinceNow
                RestLog.add(String(format: "区間終了（%.1f秒遅れ）、鳴らす", late))
                self?.playBeep()
                index += 1
                start = end
            }
        }
    }

    func stop() async {
        RestLog.add("停止")
        stopSound()
        for activity in Activity<RestAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    // MARK: 音

    private func startSound() throws {
        guard let url = Bundle.main.url(forResource: "rest", withExtension: "wav") else {
            throw RestError.soundMissing
        }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)

        // 待ち時間用: 同じ音を音量0でループ（バックグラウンドで止まらないようにするため）
        let silent = try AVAudioPlayer(contentsOf: url)
        silent.volume = 0
        silent.numberOfLoops = -1
        silent.play()
        keepAlive = silent

        let sound = try AVAudioPlayer(contentsOf: url)
        sound.prepareToPlay()
        beep = sound
    }

    func resumeKeepAlive() {
        guard let keepAlive else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        if !keepAlive.isPlaying { keepAlive.play() }
        RestLog.add("無音ループ再開: \(keepAlive.isPlaying)")
    }

    private func playBeep() {
        if let keepAlive, !keepAlive.isPlaying {
            RestLog.add("無音ループが止まっていた")
            keepAlive.play()
        }
        guard let beep else { RestLog.add("ビープがない"); return }
        beep.currentTime = 0
        beep.volume = 1
        beep.play()
    }

    private func stopSound() {
        loop?.cancel()
        loop = nil
        keepAlive?.stop()
        beep?.stop()
        keepAlive = nil
        beep = nil
        // ほかのアプリ（音楽）に、こちらの再生が終わったことを伝える
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: ライブアクティビティ

    private func setState(_ state: RestAttributes.ContentState) async throws {
        let content = ActivityContent(state: state, staleDate: nil)
        if let activity = Activity<RestAttributes>.activities.first {
            await activity.update(content)
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw RestError.activitiesDisabled }
        _ = try Activity.request(attributes: RestAttributes(), content: content)
    }
}

/// ショートカットアプリから実行したときに、理由がそのまま表示される
/// 動作の記録。アプリの画面（React Native の Settings）で "restLog" を表示する。最新40行だけ残す。
enum RestLog {
    static let key = "restLog"

    static func add(_ message: String) {
        let time = Date().formatted(date: .omitted, time: .standard)
        var lines = (UserDefaults.standard.string(forKey: key) ?? "").split(separator: "\n").map(String.init)
        lines.append("\(time) \(message)")
        UserDefaults.standard.set(lines.suffix(40).joined(separator: "\n"), forKey: key)
    }
}

enum RestError: Error, CustomLocalizedStringResourceConvertible {
    case soundMissing
    case noPreset
    case activitiesDisabled

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .soundMissing: return "音のファイルが見つかりません"
        case .noPreset: return "そのプリセットは設定されていません"
        case .activitiesDisabled: return "ライブアクティビティがオフです（設定 → Rest Timer でオンにしてください）"
        }
    }
}
