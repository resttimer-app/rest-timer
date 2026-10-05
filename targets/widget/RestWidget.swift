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
                    Text("休憩タイマー")
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
                Text("休憩タイマー")
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
        .configurationDisplayName("休憩タイマー")
        .description("タップすると、ロック画面に時間のメニューが出ます。")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - ロック画面の下のボタン（コントロール、iOS 18〜）: 長押しでメニューを出す

struct RestControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "RestControl") {
            ControlWidgetButton(action: ShowRestMenuIntent()) {
                Label("休憩タイマー", systemImage: "timer")
            }
        }
        .displayName("休憩タイマー")
        .description("押すと、ロック画面に時間のメニューが出ます。")
    }
}

// MARK: - ロック画面のメニューとカウントダウン（ライブアクティビティ）

struct RestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestAttributes.self) { context in
            Group {
                if let running = context.state.running {
                    RunningView(running: running)
                } else if let number = context.state.choosing,
                          context.state.presets.indices.contains(number - 1)
                {
                    StartPointView(number: number, preset: context.state.presets[number - 1])
                } else {
                    MenuView(presets: context.state.presets)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer")
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let running = context.state.running {
                        countdown(running)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .frame(maxWidth: 110)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let running = context.state.running {
                        HStack {
                            SegmentsLine(running: running)
                            Spacer()
                            Button(intent: StopRestIntent()) {
                                Text("停止")
                            }
                            .tint(.red)
                        }
                    } else {
                        Text("ロック画面で時間を選んでください")
                            .font(.caption)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                if let running = context.state.running {
                    countdown(running)
                        .frame(maxWidth: 44)
                }
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }
}

/// メニュー1段階目: プリセットを横幅いっぱいの2列×3段に並べる（閉じるボタンは右上の隅）
private struct MenuView: View {
    let presets: [RestPreset]

    /// 2個ずつの行に分ける
    private var rows: [[(Int, RestPreset)]] {
        let items = Array(presets.enumerated()).map { ($0.offset, $0.element) }
        return stride(from: 0, to: items.count, by: 2).map { Array(items[$0..<min($0 + 2, items.count)]) }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if presets.isEmpty {
                Text("アプリでプリセットを設定してください")
                    .font(.headline)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 6) {
                            ForEach(row, id: \.0) { index, preset in
                                PresetButton(number: index + 1, preset: preset)
                            }
                            if row.count == 1 {
                                Color.clear.frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            Button(intent: StopRestIntent()) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.black.opacity(0.55)))
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: -6)
        }
    }
}

private struct PresetButton: View {
    let number: Int
    let preset: RestPreset

    var body: some View {
        Button(intent: ChoosePresetIntent(number: number)) {
            HStack(spacing: 8) {
                Text("\(number)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .opacity(0.75)
                Text(preset.label)
                    .font(.system(size: preset.segments.count <= 2 ? 19 : 15, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 42, maxHeight: 42)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

/// メニュー2段階目: どの区間から始めるかを、大きなボタンで横一列に並べる
private struct StartPointView: View {
    let number: Int
    let preset: RestPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(number)  \(preset.label)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("どこから始める？")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button(intent: ShowRestMenuIntent()) {
                    Label("戻る", systemImage: "chevron.left")
                        .font(.footnote.bold())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                ForEach(Array(preset.segments.enumerated()), id: \.offset) { i, seconds in
                    Button(intent: StartPresetIntent(number: number, startAt: i + 1)) {
                        Text(RestPreset.format(seconds))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(maxWidth: .infinity, minHeight: 60, maxHeight: 60)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// 区間の並び。今の区間だけ色を付ける（2分 → [3分] → 5分）
private struct SegmentsLine: View {
    let running: RestAttributes.Running

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(running.segments.enumerated()), id: \.offset) { i, seconds in
                if i > 0 {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                Text(RestPreset.format(seconds))
                    .font(.system(size: 13, weight: i == running.index ? .bold : .regular, design: .rounded))
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(i == running.index ? Color.orange : Color.clear))
                    .foregroundStyle(i == running.index ? Color.white : Color.secondary)
            }
        }
        .minimumScaleFactor(0.6)
    }
}

/// カウント中: 区間の並び（今の区間に色）、残り時間、次の区間、停止ボタン
private struct RunningView: View {
    let running: RestAttributes.Running

    private var next: Int {
        running.segments[(running.index + 1) % running.segments.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SegmentsLine(running: running)
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("残り")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    countdown(running)
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(running.count)本目")
                        .font(.caption)
                    Text("次: \(RestPreset.format(next))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button(intent: StopRestIntent()) {
                    Text("停止")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 44)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.red))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

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
