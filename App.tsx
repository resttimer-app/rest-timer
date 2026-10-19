import { StatusBar } from "expo-status-bar";
import { useEffect, useState } from "react";
import { Modal, Pressable, ScrollView, Settings, StyleSheet, Text, View } from "react-native";

// Swift 側（PresetStore）が UserDefaults の "restPresetsSec" を読む。形式は秒の配列の配列 [[120,180],[300,1500],[],...]
const KEY = "restPresetsSec";
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

function format(sec: number): string {
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  if (m === 0) return `${s}秒`;
  if (s === 0) return `${m}分`;
  return `${m}分${s}秒`;
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

/** どこを編集中か。index が segments.length なら「追加」 */
type Editing = { row: number; index: number } | null;

export default function App() {
  const [presets, setPresets] = useState<number[][]>(load);
  const [editing, setEditing] = useState<Editing>(null);
  const [showLog, setShowLog] = useState(false);
  const [log, setLog] = useState("");

  // 変更はその場で保存（保存ボタンなし）
  useEffect(() => {
    Settings.set({ [KEY]: JSON.stringify(presets) });
  }, [presets]);

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
    editing !== null && editing.index < presets[editing.row].length
      ? presets[editing.row][editing.index]
      : null;

  return (
    <View style={styles.screen}>
      <ScrollView contentContainerStyle={styles.container}>
        <Text style={styles.title}>休憩タイマー</Text>
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

        <Text style={styles.note}>時間をタップで変更。区間は5つまで、順番に繰り返します。</Text>

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
      <StatusBar style="light" />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: C.bg },
  container: { padding: 20, paddingTop: 76, paddingBottom: 48, gap: 10 },
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
