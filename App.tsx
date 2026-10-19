import { StatusBar } from "expo-status-bar";
import { SymbolView } from "expo-symbols";
import { useEffect, useState } from "react";
import { Modal, Pressable, ScrollView, Settings, StyleSheet, Text, View } from "react-native";

import { startPreset, stopTimer } from "./modules/mixtimer-bridge";

// Swift 側（PresetStore）が UserDefaults の "restPresetsSec" を読む。形式は秒の配列の配列 [[120,180],[300,1500],[],...]
const KEY = "restPresetsSec";
// Swift 側（RestStatus）が書く、今のタイマーの状態
const STATUS_KEY = "restStatus";
const ROWS = 6;
const MAX_SEGMENTS = 5;
const DEFAULTS: number[][] = [[120, 180], [300, 1500], [], [], [], []];

// 選べる長さ: 5分までは30秒刻み、20分までは1分刻み、その上は30分・45分・60分
const GROUPS: { title: string; options: number[] }[] = [
  { title: "〜5分", options: Array.from({ length: 10 }, (_, i) => (i + 1) * 30) },
  { title: "6〜20分", options: Array.from({ length: 15 }, (_, i) => (i + 6) * 60) },
  { title: "長め", options: [1800, 2700, 3600] },
];

// ロック画面と同じ色
const C = {
  bg: "#0E0E12",
  card: "#1A1A20",
  stroke: "#2A2A32",
  text: "#FFFFFF",
  sub: "#8C8C96",
  accent: "#FF8C47",
  accentSoft: "rgba(255,140,71,0.14)",
  danger: "#FF4545",
};

type Status = {
  running: boolean;
  label?: string;
  segments?: number[];
  index?: number;
  count?: number;
  start?: number;
  end?: number;
};

function format(sec: number): string {
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  if (m === 0) return `${s}秒`;
  if (s === 0) return `${m}分`;
  return `${m}分${s}秒`;
}

function clock(sec: number): string {
  const s = Math.max(0, Math.ceil(sec));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
}

function label(segments: number[]): string {
  const parts = segments.map(format);
  return parts.join(parts.length === 2 ? "↔" : "→");
}

function load(): number[][] {
  try {
    const lists = JSON.parse(Settings.get(KEY) ?? "null");
    if (Array.isArray(lists)) {
      return Array.from({ length: ROWS }, (_, i) => (Array.isArray(lists[i]) ? lists[i] : []));
    }
  } catch {}
  return DEFAULTS;
}

function readStatus(): Status {
  try {
    return JSON.parse(Settings.get(STATUS_KEY) ?? "null") ?? { running: false };
  } catch {
    return { running: false };
  }
}

/**
 * 区間の終わりを過ぎていたら、次の区間へ進めた状態を計算する（本体からの更新を待たずに表示を進める）
 */
function current(status: Status, now: number) {
  if (!status.running || !status.segments?.length || status.end == null || status.start == null) return null;
  const segs = status.segments;
  let index = status.index ?? 0;
  let count = status.count ?? 1;
  let start = status.start;
  let end = status.end;
  while (now >= end) {
    index = (index + 1) % segs.length;
    count += 1;
    start = end;
    end = start + segs[index];
  }
  return { segments: segs, index, count, start, end, label: status.label ?? label(segs) };
}

export default function App() {
  const [tab, setTab] = useState<"timer" | "settings">("timer");
  const [presets, setPresets] = useState<number[][]>(load);

  // 変更はその場で保存（保存ボタンなし）
  useEffect(() => {
    Settings.set({ [KEY]: JSON.stringify(presets) });
  }, [presets]);

  return (
    <View style={styles.screen}>
      {tab === "timer" ? <TimerTab presets={presets} /> : <SettingsTab presets={presets} setPresets={setPresets} />}

      <View style={styles.tabBar}>
        <TabButton symbol="timer" title="タイマー" active={tab === "timer"} onPress={() => setTab("timer")} />
        <TabButton symbol="slider.horizontal.3" title="設定" active={tab === "settings"} onPress={() => setTab("settings")} />
      </View>
      <StatusBar style="light" />
    </View>
  );
}

function TabButton(props: { symbol: string; title: string; active: boolean; onPress: () => void }) {
  const color = props.active ? C.accent : C.sub;
  return (
    <Pressable style={styles.tabButton} onPress={props.onPress}>
      <SymbolView name={props.symbol as never} size={24} tintColor={color} />
      <Text style={[styles.tabTitle, { color }]}>{props.title}</Text>
    </Pressable>
  );
}

// MARK: タイマー

function TimerTab({ presets }: { presets: number[][] }) {
  const [status, setStatus] = useState<Status>(readStatus);
  const [now, setNow] = useState(Date.now() / 1000);

  useEffect(() => {
    const id = setInterval(() => {
      setStatus(readStatus());
      setNow(Date.now() / 1000);
    }, 250);
    return () => clearInterval(id);
  }, []);

  const run = current(status, now);
  const items = presets.map((segs, i) => ({ number: i + 1, segs })).filter((p) => p.segs.length > 0);

  return (
    <View style={styles.timerScreen}>
      {/* 上: 今の状態を大きく */}
      <View style={styles.statusArea}>
        {run ? (
          <>
            <View style={styles.segLine}>
              {run.segments.map((sec, i) => (
                <View key={i} style={[styles.segPill, i === run.index && styles.segPillActive]}>
                  <Text style={[styles.segPillText, i === run.index && styles.segPillTextActive]}>{format(sec)}</Text>
                </View>
              ))}
            </View>
            <Text style={styles.bigClock}>{clock(run.end - now)}</Text>
            <View style={styles.progressTrack}>
              <View
                style={[
                  styles.progressFill,
                  { width: `${Math.min(100, Math.max(0, ((run.end - now) / (run.end - run.start)) * 100))}%` },
                ]}
              />
            </View>
            <Text style={styles.runInfo}>
              {run.count}本目　次 {format(run.segments[(run.index + 1) % run.segments.length])}
            </Text>
            <Pressable style={styles.stopButton} onPress={stopTimer}>
              <SymbolView name="stop.fill" size={28} tintColor="#FFFFFF" />
            </Pressable>
          </>
        ) : (
          <>
            <Text style={styles.idleClock}>--:--</Text>
            <Text style={styles.idleText}>下のプリセットを押すと、すぐ始まります</Text>
          </>
        )}
      </View>

      {/* 下: プリセットを押すと1発で開始。区間の時間を押すと、その区間から開始 */}
      <ScrollView style={styles.presetList} contentContainerStyle={{ gap: 10, paddingBottom: 16 }}>
        {items.length === 0 && <Text style={styles.idleText}>「設定」でプリセットを作ってください</Text>}
        {items.map(({ number, segs }) => (
          <Pressable key={number} style={styles.presetCard} onPress={() => startPreset(number, 1)}>
            <View style={styles.badge}>
              <Text style={styles.badgeText}>{number}</Text>
            </View>
            <View style={styles.segs}>
              {segs.map((sec, i) => (
                <Pressable key={i} style={styles.startChip} onPress={() => startPreset(number, i + 1)} hitSlop={4}>
                  <Text style={styles.startChipText}>{format(sec)}</Text>
                </Pressable>
              ))}
            </View>
            <SymbolView name="play.fill" size={18} tintColor={C.accent} />
          </Pressable>
        ))}
        <Text style={styles.note}>カードを押すと最初の区間から、時間を押すとその区間から始まります。</Text>
      </ScrollView>
    </View>
  );
}

// MARK: 設定

/** どこを編集中か。index が segments.length なら「追加」 */
type Editing = { row: number; index: number } | null;

function SettingsTab(props: { presets: number[][]; setPresets: (f: (p: number[][]) => number[][]) => void }) {
  const { presets, setPresets } = props;
  const [editing, setEditing] = useState<Editing>(null);
  const [showLog, setShowLog] = useState(false);
  const [log, setLog] = useState("");

  const update = (row: number, segments: number[]) =>
    setPresets((p) => p.map((s, i) => (i === row ? segments : s)));

  const choose = (sec: number) => {
    if (!editing) return;
    const segs = [...presets[editing.row]];
    segs[editing.index] = sec;
    update(editing.row, segs);
    setEditing(null);
  };

  const remove = () => {
    if (!editing) return;
    update(
      editing.row,
      presets[editing.row].filter((_, i) => i !== editing.index),
    );
    setEditing(null);
  };

  const selected =
    editing !== null && editing.index < presets[editing.row].length ? presets[editing.row][editing.index] : null;

  return (
    <>
      <ScrollView contentContainerStyle={styles.container}>
        <Text style={styles.title}>プリセット</Text>
        <Text style={styles.hint}>ロック画面のボタンを長押し → プリセットを選ぶだけ</Text>

        {presets.map((segs, row) => (
          <View key={row} style={styles.card}>
            <View style={styles.badge}>
              <Text style={styles.badgeText}>{row + 1}</Text>
            </View>
            <View style={styles.segs}>
              {segs.map((sec, i) => (
                <View key={i} style={styles.segWrap}>
                  {i > 0 && <Text style={styles.arrow}>›</Text>}
                  <Pressable style={styles.chip} onPress={() => setEditing({ row, index: i })}>
                    <Text style={styles.chipText}>{format(sec)}</Text>
                  </Pressable>
                </View>
              ))}
              {segs.length < MAX_SEGMENTS && (
                <Pressable
                  style={[styles.add, segs.length === 0 && styles.addEmpty]}
                  onPress={() => setEditing({ row, index: segs.length })}
                >
                  <Text style={styles.addText}>{segs.length === 0 ? "＋ 時間を追加" : "＋"}</Text>
                </Pressable>
              )}
            </View>
          </View>
        ))}

        <Text style={styles.note}>時間をタップで変更。区間は5つまで、順番にくり返します。</Text>

        <Pressable
          onPress={() => {
            setLog(Settings.get("restLog") ?? "");
            setShowLog((v) => !v);
          }}
        >
          <Text style={styles.logToggle}>{showLog ? "動作の記録を閉じる" : "動作の記録"}</Text>
        </Pressable>
        {showLog && (
          <Text style={styles.log} selectable>
            {log === "" ? "まだ記録はありません" : log.split("\n").reverse().join("\n")}
          </Text>
        )}
      </ScrollView>

      <Modal visible={editing !== null} transparent animationType="slide" onRequestClose={() => setEditing(null)}>
        <Pressable style={styles.backdrop} onPress={() => setEditing(null)} />
        <View style={styles.sheet}>
          <View style={styles.sheetHeader}>
            <Text style={styles.sheetTitle}>時間を選ぶ</Text>
            {selected !== null && (
              <Pressable onPress={remove} hitSlop={10}>
                <Text style={styles.delete}>削除</Text>
              </Pressable>
            )}
          </View>
          <ScrollView>
            {GROUPS.map((g) => (
              <View key={g.title} style={styles.group}>
                <Text style={styles.groupTitle}>{g.title}</Text>
                <View style={styles.grid}>
                  {g.options.map((sec) => (
                    <Pressable
                      key={sec}
                      style={[styles.option, sec === selected && styles.optionSelected]}
                      onPress={() => choose(sec)}
                    >
                      <Text style={[styles.optionText, sec === selected && styles.optionTextSelected]}>
                        {format(sec)}
                      </Text>
                    </Pressable>
                  ))}
                </View>
              </View>
            ))}
          </ScrollView>
        </View>
      </Modal>
    </>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: C.bg },

  tabBar: {
    flexDirection: "row",
    borderTopColor: C.stroke,
    borderTopWidth: StyleSheet.hairlineWidth,
    backgroundColor: C.bg,
    paddingTop: 8,
    paddingBottom: 30,
  },
  tabButton: { flex: 1, alignItems: "center", gap: 3 },
  tabTitle: { fontSize: 11, fontWeight: "600" },

  timerScreen: { flex: 1, paddingTop: 64, paddingHorizontal: 20 },
  statusArea: { alignItems: "center", paddingVertical: 12, gap: 14, minHeight: 330, justifyContent: "center" },
  segLine: { flexDirection: "row", flexWrap: "wrap", justifyContent: "center", gap: 6 },
  segPill: { borderColor: C.stroke, borderWidth: 1, borderRadius: 999, paddingVertical: 4, paddingHorizontal: 12 },
  segPillActive: { backgroundColor: C.accent, borderColor: C.accent },
  segPillText: { color: C.sub, fontSize: 14, fontWeight: "600" },
  segPillTextActive: { color: "#000" },
  bigClock: { color: C.text, fontSize: 104, fontWeight: "300", fontVariant: ["tabular-nums"], letterSpacing: -2 },
  progressTrack: { width: "80%", height: 6, borderRadius: 3, backgroundColor: C.card, overflow: "hidden" },
  progressFill: { height: 6, backgroundColor: C.accent },
  runInfo: { color: C.sub, fontSize: 15 },
  stopButton: {
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: C.danger,
    alignItems: "center",
    justifyContent: "center",
    marginTop: 6,
  },
  idleClock: { color: C.stroke, fontSize: 104, fontWeight: "300" },
  idleText: { color: C.sub, fontSize: 14, textAlign: "center" },

  presetList: { flex: 1 },
  presetCard: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    backgroundColor: C.card,
    borderColor: C.stroke,
    borderWidth: StyleSheet.hairlineWidth,
    borderRadius: 16,
    paddingHorizontal: 14,
    minHeight: 64,
  },
  startChip: { backgroundColor: C.bg, borderRadius: 10, paddingVertical: 8, paddingHorizontal: 12 },
  startChipText: { color: C.text, fontSize: 17, fontWeight: "600" },

  container: { padding: 20, paddingTop: 64, paddingBottom: 48, gap: 10 },
  title: { fontSize: 30, fontWeight: "700", color: C.text },
  hint: { fontSize: 14, color: C.sub, marginBottom: 12 },

  card: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    backgroundColor: C.card,
    borderColor: C.stroke,
    borderWidth: StyleSheet.hairlineWidth,
    borderRadius: 16,
    padding: 14,
    minHeight: 64,
  },
  badge: { width: 26, height: 26, borderRadius: 13, backgroundColor: C.accent, alignItems: "center", justifyContent: "center" },
  badgeText: { color: "#000", fontSize: 14, fontWeight: "700" },
  segs: { flex: 1, flexDirection: "row", flexWrap: "wrap", alignItems: "center", gap: 6 },
  segWrap: { flexDirection: "row", alignItems: "center", gap: 6 },
  arrow: { color: C.sub, fontSize: 18 },
  chip: { backgroundColor: C.accentSoft, borderRadius: 10, paddingVertical: 7, paddingHorizontal: 12 },
  chipText: { color: C.accent, fontSize: 16, fontWeight: "600" },
  add: { borderColor: C.stroke, borderWidth: 1, borderRadius: 10, paddingVertical: 6, paddingHorizontal: 12 },
  addEmpty: { borderStyle: "dashed" },
  addText: { color: C.sub, fontSize: 15 },
  note: { fontSize: 12, color: C.sub, marginTop: 4 },

  logToggle: { color: C.sub, fontSize: 12, textDecorationLine: "underline", marginTop: 24 },
  log: { fontFamily: "Menlo", fontSize: 11, lineHeight: 16, color: C.sub, backgroundColor: C.card, padding: 10, borderRadius: 10 },

  backdrop: { flex: 1, backgroundColor: "rgba(0,0,0,0.5)" },
  sheet: { maxHeight: "70%", backgroundColor: C.card, borderTopLeftRadius: 20, borderTopRightRadius: 20, paddingBottom: 36 },
  sheetHeader: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", padding: 20, paddingBottom: 8 },
  sheetTitle: { fontSize: 17, fontWeight: "700", color: C.text },
  delete: { color: C.danger, fontSize: 15, fontWeight: "600" },
  group: { paddingHorizontal: 20, paddingTop: 12 },
  groupTitle: { fontSize: 12, color: C.sub, marginBottom: 8 },
  grid: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  option: {
    width: "23%",
    paddingVertical: 12,
    borderRadius: 10,
    backgroundColor: C.bg,
    borderColor: C.stroke,
    borderWidth: StyleSheet.hairlineWidth,
    alignItems: "center",
  },
  optionSelected: { backgroundColor: C.accent, borderColor: C.accent },
  optionText: { color: C.text, fontSize: 14, fontWeight: "500" },
  optionTextSelected: { color: "#000", fontWeight: "700" },
});
