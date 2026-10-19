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
            .activitySystemActionForegroundColor(Theme.accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if shown(context) != nil {
                        Button(intent: StopRestIntent()) {
                            roundIcon("xmark", size: 44)
                        }
                        .buttonStyle(.plain)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let running = shown(context) {
                        countdown(running)
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(Theme.accent)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140, alignment: .trailing)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let running = shown(context) {
                        Text("\(RestPreset.format(running.segmentSeconds))・\(running.count)本目")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondary)
                    } else {
                        Text("ロック画面で時間を選んでください")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(Theme.accent)
            } compactTrailing: {
                if let running = shown(context) {
                    countdown(running)
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: 46)
                }
            } minimal: {
                // 音楽など他のライブアクティビティと並ぶと、この小さい丸だけになる。ここにも残り時間を出す
                if let running = shown(context) {
                    countdown(running)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: 36)
                } else {
                    Image(systemName: "timer")
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }
}

// MARK: - 見た目の共通部品（Apple の時計アプリのタイマー風: 大きな数字、小さな文字、丸ボタンだけ）

private enum Theme {
    static let accent = Color.orange
    static let secondary = Color.white.opacity(0.6)
    static let button = Color.white.opacity(0.16)
}

/// 丸ボタンの中身
private func roundIcon(_ name: String, size: CGFloat, tint: Color = Theme.button, foreground: Color = .white) -> some View {
    Image(systemName: name)
        .font(.system(size: size * 0.36, weight: .semibold))
        .foregroundStyle(foreground)
        .frame(width: size, height: size)
        .background(Circle().fill(tint))
}

/// 角の丸いボタンの中身（文字）
private func pill<Content: View>(height: CGFloat, @ViewBuilder _ content: () -> Content) -> some View {
    content()
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .background(RoundedRectangle(cornerRadius: height / 2, style: .continuous).fill(Theme.button))
}

// MARK: - メニュー1段階目

/// プリセットを横幅いっぱいに3段ずつ並べ、2ページを › ‹ で切り替える（1〜3番 / 4〜6番）。
/// ライブアクティビティはスワイプを受け付けないので、ボタンで切り替えて、横にスライドする動きを付けている。
/// 高さは160ptまでなので、3段にして1段を約42ptにしている。
private struct MenuView: View {
    let presets: [RestPreset]
    let page: Int

    private var pageCount: Int { (presets.count + 2) / 3 }
    private var current: Int { min(max(page, 0), max(pageCount - 1, 0)) }

    var body: some View {
        HStack(spacing: 12) {
            if presets.isEmpty {
                Text("アプリでプリセットを設定してください")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 6) {
                    ForEach(current * 3..<min(current * 3 + 3, presets.count), id: \.self) { index in
                        Button(intent: ChoosePresetIntent(number: index + 1)) {
                            pill(height: 42) {
                                Text(presets[index].label)
                                    .font(.system(size: 19, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                    .padding(.horizontal, 16)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
                .id(current)
                .transition(.push(from: current == 0 ? .leading : .trailing))
            }
            // 右端: 閉じる / ページ切り替え
            VStack(spacing: 6) {
                Button(intent: StopRestIntent()) {
                    roundIcon("xmark", size: 54)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                if pageCount > 1 {
                    Button(intent: MenuPageIntent(page: current == 0 ? 1 : 0)) {
                        roundIcon(current == 0 ? "chevron.right" : "chevron.left", size: 54)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 54)
        }
    }
}

// MARK: - メニュー2段階目

/// どの区間から始めるかを、丸いボタンで横一列に並べる
private struct StartPointView: View {
    let number: Int
    let preset: RestPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("どこから始めますか")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                Spacer(minLength: 0)
                Button(intent: MenuPageIntent(page: (number - 1) / 3)) {
                    roundIcon("chevron.left", size: 34)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 8) {
                ForEach(Array(preset.segments.enumerated()), id: \.offset) { i, seconds in
                    Button(intent: StartPresetIntent(number: number, startAt: i + 1)) {
                        pill(height: 56) {
                            Text(RestPreset.format(seconds))
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .padding(.horizontal, 6)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - カウント中

/// 時計アプリのタイマーと同じ並び: 左に丸ボタン、右に小さな説明と大きな残り時間
private struct RunningView: View {
    let running: RestAttributes.Running

    private var next: Int {
        running.segments[(running.index + 1) % running.segments.count]
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(intent: StopRestIntent()) {
                roundIcon("xmark", size: 52)
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(RestPreset.format(running.segmentSeconds))・次 \(RestPreset.format(next))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
                countdown(running)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(Theme.accent)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
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
