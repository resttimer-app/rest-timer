import { StatusBar } from "expo-status-bar";
import { useState } from "react";
import { Alert, Modal, Pressable, ScrollView, Settings, StyleSheet, Text, View } from "react-native";

// Swift 側（PresetStore）が UserDefaults の "restPresetsSec" を読む。形式は秒の配列の配列 [[120,180],[300,1500],[],...]
const KEY = "restPresetsSec";
const ROWS = 6;
const MAX_SEGMENTS = 5;
const DEFAULTS: number[][] = [[120, 180], [300, 1500], [], [], [], []];

// 選べる長さ: 5分までは30秒刻み、20分までは1分刻み、その上は30分・45分・60分
const OPTIONS: number[] = [
  ...Array.from({ length: 10 }, (_, i) => (i + 1) * 30),
  ...Array.from({ length: 15 }, (_, i) => (i + 6) * 60),
  1800,
  2700,
  3600,
];

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
  const [log, setLog] = useState<string>(() => Settings.get("restLog") ?? "");

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

  const save = () => {
    Settings.set({ [KEY]: JSON.stringify(presets) });
    Alert.alert("保存しました", "次にロック画面のボタンを押したときから反映されます。");
  };

  const editingExisting = editing !== null && editing.index < presets[editing.row].length;

  return (
    <View style={styles.screen}>
      <ScrollView contentContainerStyle={styles.container}>
        <Text style={styles.title}>休憩タイマー</Text>
        <Text style={styles.body}>
          ロック画面のボタンを長押しすると、下の表のプリセットがロック画面に並びます。プリセットを選び、次にどの区間から始めるかを選ぶと、「停止」を押すまで区間の順に繰り返し鳴ります。
        </Text>

        <View style={styles.table}>
          {presets.map((segs, row) => (
            <View key={row} style={[styles.row, row > 0 && styles.rowBorder]}>
              <Text style={styles.num}>{row + 1}</Text>
              <View style={styles.segs}>
                {segs.map((sec, i) => (
                  <View key={i} style={styles.segWrap}>
                    {i > 0 && <Text style={styles.arrow}>→</Text>}
                    <Pressable style={styles.chip} onPress={() => setEditing({ row, index: i })}>
                      <Text style={styles.chipText}>{format(sec)} ▾</Text>
                    </Pressable>
                  </View>
                ))}
                {segs.length < MAX_SEGMENTS && (
                  <Pressable style={styles.add} onPress={() => setEditing({ row, index: segs.length })}>
                    <Text style={styles.addText}>＋</Text>
                  </Pressable>
                )}
                {segs.length > 0 && (
                  <Text style={styles.repeat}>{segs.length === 1 ? "を繰り返し" : "→ 最初へ"}</Text>
                )}
              </View>
            </View>
          ))}
        </View>
        <Text style={styles.note}>
          時間をタップすると変更・削除、＋で区間を足せます（1行に5つまで）。例: 5分 → 10分 → 25分 なら、その順で止めるまで繰り返します。区間のない行はロック画面に出ません。
        </Text>

        <Pressable style={styles.button} onPress={save}>
          <Text style={styles.buttonText}>保存</Text>
        </Pressable>

        <View style={styles.logHeader}>
          <Text style={styles.section}>動作の記録（不具合調査用）</Text>
          <Pressable onPress={() => setLog(Settings.get("restLog") ?? "")}>
            <Text style={styles.reload}>更新</Text>
          </Pressable>
        </View>
        <Text style={styles.log} selectable>
          {log === "" ? "まだ記録はありません" : log.split("\n").reverse().join("\n")}
        </Text>
      </ScrollView>

      <Modal visible={editing !== null} transparent animationType="slide" onRequestClose={() => setEditing(null)}>
        <Pressable style={styles.backdrop} onPress={() => setEditing(null)} />
        <View style={styles.sheet}>
          <View style={styles.sheetHeader}>
            <Text style={styles.sheetTitle}>
              {editing ? `${editing.row + 1}番 ・ ${editing.index + 1}つ目の区間` : ""}
            </Text>
            {editingExisting && (
              <Pressable onPress={remove}>
                <Text style={styles.delete}>この区間を削除</Text>
              </Pressable>
            )}
          </View>
          <ScrollView>
            {OPTIONS.map((sec) => {
              const selected = editingExisting && presets[editing!.row][editing!.index] === sec;
              return (
                <Pressable key={sec} style={[styles.option, selected && styles.optionSelected]} onPress={() => choose(sec)}>
                  <Text style={[styles.optionText, selected && styles.optionTextSelected]}>{format(sec)}</Text>
                </Pressable>
              );
            })}
          </ScrollView>
        </View>
      </Modal>
      <StatusBar style="auto" />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: "#fff" },
  container: { padding: 20, paddingTop: 72, gap: 12 },
  title: { fontSize: 28, fontWeight: "700" },
  body: { fontSize: 14, lineHeight: 21, color: "#333" },
  table: { borderWidth: 1, borderColor: "#ddd", borderRadius: 12, marginTop: 8 },
  row: { flexDirection: "row", alignItems: "center", padding: 10, gap: 10, minHeight: 56 },
  rowBorder: { borderTopWidth: 1, borderTopColor: "#eee" },
  num: { width: 18, fontSize: 16, fontWeight: "700", color: "#999", textAlign: "center" },
  segs: { flex: 1, flexDirection: "row", flexWrap: "wrap", alignItems: "center", gap: 6 },
  segWrap: { flexDirection: "row", alignItems: "center", gap: 6 },
  arrow: { color: "#999" },
  chip: { backgroundColor: "#fff3e6", borderColor: "#f5a54a", borderWidth: 1, borderRadius: 8, paddingVertical: 6, paddingHorizontal: 10 },
  chipText: { fontSize: 15, fontWeight: "600", color: "#b35f00" },
  add: { borderColor: "#ccc", borderWidth: 1, borderStyle: "dashed", borderRadius: 8, paddingVertical: 5, paddingHorizontal: 12 },
  addText: { fontSize: 16, color: "#888" },
  repeat: { fontSize: 11, color: "#999" },
  note: { fontSize: 12, color: "#777", lineHeight: 18 },
  button: { backgroundColor: "#111", padding: 14, borderRadius: 12, alignItems: "center", marginTop: 4 },
  buttonText: { color: "#fff", fontSize: 16, fontWeight: "600" },
  section: { fontSize: 16, fontWeight: "700" },
  logHeader: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginTop: 20 },
  reload: { color: "#0a7aff", fontSize: 15 },
  log: { fontFamily: "Menlo", fontSize: 11, lineHeight: 16, color: "#444", backgroundColor: "#f5f5f5", padding: 10, borderRadius: 8 },
  backdrop: { flex: 1, backgroundColor: "rgba(0,0,0,0.3)" },
  sheet: { maxHeight: "60%", backgroundColor: "#fff", borderTopLeftRadius: 16, borderTopRightRadius: 16, paddingBottom: 32 },
  sheetHeader: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", padding: 16 },
  sheetTitle: { fontSize: 16, fontWeight: "700" },
  delete: { color: "#d00", fontSize: 14 },
  option: { paddingVertical: 12, paddingHorizontal: 20 },
  optionSelected: { backgroundColor: "#fff3e6" },
  optionText: { fontSize: 17 },
  optionTextSelected: { fontWeight: "700", color: "#b35f00" },
});
