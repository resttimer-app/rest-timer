import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - ウィジェット（ホーム画面・ロック画面）: タップでメニューを出す

struct RestEntry: TimelineEntry {
    let date: Date
}

struct RestProvider: TimelineProvider {
    func placeholder(in context: Context) -> RestEntry { RestEntry(date: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (RestEntry) -> Void) {
        completion(RestEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RestEntry>) -> Void) {
        completion(Timeline(entries: [RestEntry(date: Date())], policy: .never))
    }
}

struct RestWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RestEntry

    var body: some View {
        Button(intent: ShowRestMenuIntent()) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "timer")
                    .font(.system(size: 22, weight: .semibold))
            }
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.system(size: 22, weight: .semibold))
                VStack(alignment: .leading, spacing: 0) {
                    Text("MixTimer")
                        .font(.headline)
                    Text("タップで時間を選ぶ")
                        .font(.caption2)
                }
                Spacer(minLength: 0)
            }
        default:
            VStack(spacing: 6) {
                Image(systemName: "timer")
                    .font(.system(size: 32, weight: .semibold))
                Text("MixTimer")
                    .font(.headline)
                Text("タップで時間を選ぶ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct RestWidget: Widget {
    let kind = "RestWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RestProvider()) { entry in
            RestWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("MixTimer")
        .description("タップすると、ロック画面に時間のメニューが出ます。")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - ロック画面の下のボタン（コントロール、iOS 18〜）: 長押しでメニューを出す

struct RestControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "RestControl") {
            ControlWidgetButton(action: ShowRestMenuIntent()) {
                Label("MixTimer", systemImage: "timer")
            }
        }
        .displayName("MixTimer")
        .description("押すと、ロック画面に時間のメニューが出ます。")
    }
}

// MARK: - ロック画面のメニューとカウントダウン（ライブアクティビティ）

struct RestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestAttributes.self) { context in
            Group {
                if let running = shown(context) {
                    RunningView(running: running)
                } else if let number = context.state.choosing,
                          context.state.presets.indices.contains(number - 1)
                {
                    StartPointView(number: number, preset: context.state.presets[number - 1])
                } else {
                    MenuView(presets: context.state.presets, page: context.state.page)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .activityBackgroundTint(Theme.background)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.accentColor)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let running = shown(context) {
                        countdown(running)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .frame(maxWidth: 110)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let running = shown(context) {
                        HStack {
                            SegmentsLine(running: running)
                            Spacer()
                            Button(intent: StopRestIntent()) {
                                roundIcon("stop.fill", size: 34, tint: Theme.stop)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Text("ロック画面で時間を選んでください")
                            .font(.caption)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(Theme.accentColor)
            } compactTrailing: {
                if let running = shown(context) {
                    countdown(running)
                        .frame(maxWidth: 44)
                }
            } minimal: {
                // 音楽など他のライブアクティビティと並ぶと、この小さい丸だけになる。ここにも残り時間を出す
                if let running = shown(context) {
                    countdown(running)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: 36)
                } else {
                    Image(systemName: "timer")
                }
            }
        }
    }
}

// MARK: - 見た目の共通部品

/// 色と形。差し色はオレンジのグラデーション1色だけ、あとは白とグレー。
private enum Theme {
    static let background = Color(red: 0.06, green: 0.06, blue: 0.08).opacity(0.82)
    static let tile = Color.white.opacity(0.08)
    static let stroke = Color.white.opacity(0.14)
    static let secondary = Color.white.opacity(0.55)
    static let accent = LinearGradient(
        colors: [Color(red: 1.0, green: 0.66, blue: 0.24), Color(red: 1.0, green: 0.42, blue: 0.32)],
        startPoint: .leading, endPoint: .trailing
    )
    static let accentColor = Color(red: 1.0, green: 0.55, blue: 0.28)
    static let stop = Color(red: 1.0, green: 0.27, blue: 0.27).opacity(0.9)
}

/// 濃いグレーのタイル（細い縁取り付き）
private struct Tile: ViewModifier {
    var radius: CGFloat = 12
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.tile))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 0.5))
    }
}

/// 番号の丸バッジ
private struct NumberBadge: View {
    let number: Int
    var body: some View {
        Text("\(number)")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.black)
            .frame(width: 22, height: 22)
            .background(Circle().fill(Theme.accent))
    }
}

/// 丸いガラス風ボタンの中身
private func roundIcon(_ name: String, size: CGFloat, tint: Color = Color.white.opacity(0.14)) -> some View {
    Image(systemName: name)
        .font(.system(size: size * 0.34, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: size, height: size)
        .background(Circle().fill(tint))
        .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 0.5))
}

// MARK: - メニュー1段階目

/// プリセットを横幅いっぱいに3段ずつ並べ、2ページを ◀ ▶ で切り替える（1〜3番 / 4〜6番）。
/// ライブアクティビティはスワイプを受け付けないので、ボタンで切り替えて、横にスライドする動きを付けている。
/// 高さは160ptまでなので、3段にして1段を約44ptにしている。
private struct MenuView: View {
    let presets: [RestPreset]
    let page: Int

    private var pageCount: Int { (presets.count + 2) / 3 }
    private var current: Int { min(max(page, 0), max(pageCount - 1, 0)) }

    var body: some View {
        HStack(spacing: 10) {
            if presets.isEmpty {
                Text("アプリでプリセットを設定してください")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 6) {
                    ForEach(current * 3..<min(current * 3 + 3, presets.count), id: \.self) { index in
                        PresetButton(number: index + 1, preset: presets[index])
                    }
                }
                .frame(maxWidth: .infinity)
                .id(current)
                .transition(.push(from: current == 0 ? .leading : .trailing))
            }
            // 右端: 閉じる / ページ切り替え
            VStack(spacing: 8) {
                Button(intent: StopRestIntent()) {
                    roundIcon("xmark", size: 60)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                if pageCount > 1 {
                    Button(intent: ShowRestMenuIntent(page: current == 0 ? 1 : 0)) {
                        roundIcon(current == 0 ? "chevron.right" : "chevron.left", size: 48)
                    }
                    .buttonStyle(.plain)
                    HStack(spacing: 5) {
                        ForEach(0..<pageCount, id: \.self) { i in
                            Capsule()
                                .fill(i == current ? Color.white : Color.white.opacity(0.3))
                                .frame(width: i == current ? 12 : 5, height: 5)
                        }
                    }
                }
            }
            .frame(width: 60)
        }
    }
}

private struct PresetButton: View {
    let number: Int
    let preset: RestPreset

    var body: some View {
        Button(intent: ChoosePresetIntent(number: number)) {
            HStack(spacing: 12) {
                NumberBadge(number: number)
                Text(preset.label)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
            .modifier(Tile())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - メニュー2段階目

/// どの区間から始めるかを、大きなタイルで横一列に並べる
private struct StartPointView: View {
    let number: Int
    let preset: RestPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                NumberBadge(number: number)
                VStack(alignment: .leading, spacing: 0) {
                    Text(preset.label)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("どこから始める？")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                }
                Spacer(minLength: 0)
                Button(intent: ShowRestMenuIntent()) {
                    roundIcon("chevron.left", size: 36)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 8) {
                ForEach(Array(preset.segments.enumerated()), id: \.offset) { i, seconds in
                    Button(intent: StartPresetIntent(number: number, startAt: i + 1)) {
                        VStack(spacing: 3) {
                            Text(RestPreset.format(seconds))
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            Image(systemName: "play.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.accentColor)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64)
                        .modifier(Tile(radius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - カウント中

/// 区間の並び。今の区間だけ色を付ける（2分 → [3分] → 5分）
private struct SegmentsLine: View {
    let running: RestAttributes.Running

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(running.segments.enumerated()), id: \.offset) { i, seconds in
                if i > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                Text(RestPreset.format(seconds))
                    .font(.system(size: 12, weight: i == running.index ? .bold : .medium, design: .rounded))
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background {
                        if i == running.index {
                            Capsule().fill(Theme.accent)
                        } else {
                            Capsule().strokeBorder(Theme.stroke, lineWidth: 0.5)
                        }
                    }
                    .foregroundStyle(i == running.index ? Color.black : Theme.secondary)
            }
        }
        .minimumScaleFactor(0.6)
    }
}

/// 残り時間（大きく）、区間の並び、何本目・次、進行バー、停止ボタン
private struct RunningView: View {
    let running: RestAttributes.Running

    private var next: Int {
        running.segments[(running.index + 1) % running.segments.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SegmentsLine(running: running)
            HStack(alignment: .center, spacing: 14) {
                countdown(running)
                    .font(.system(size: 52, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(running.count)本目")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("次 \(RestPreset.format(next))")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondary)
                }
                Spacer(minLength: 0)
                Button(intent: StopRestIntent()) {
                    roundIcon("stop.fill", size: 52, tint: Theme.stop)
                }
                .buttonStyle(.plain)
            }
            // 残り時間の進行バー（iPhone が自動で動かす）
            ProgressView(timerInterval: running.startDate...running.endDate, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(Theme.accentColor)
        }
    }
}

/// 今表示する区間。区間の終わり（staleDate）を過ぎると iPhone が isStale にして描き直すので、
/// アプリからの更新が届く前でも次の区間を出せる。
private func shown(_ context: ActivityViewContext<RestAttributes>) -> RestAttributes.Running? {
    guard let running = context.state.running else { return nil }
    return context.isStale || running.endDate <= Date() ? running.next() : running
}

/// 残り時間。0 で止まり、増えていくことはない（iPhone が自動で数字を減らす）
private func countdown(_ running: RestAttributes.Running) -> some View {
    Text(timerInterval: running.startDate...running.endDate, countsDown: true, showsHours: false)
        .monospacedDigit()
}

@main
struct RestWidgetBundle: WidgetBundle {
    var body: some Widget {
        RestWidget()
        RestControl()
        RestLiveActivity()
    }
}
