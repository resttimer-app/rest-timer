# 休憩タイマー（筋トレ用 iPhone アプリ）引き継ぎメモ

## 目的
筋トレ中のレスト用。ホーム画面のウィジェットを1タップすると、指定秒数後に約2秒の音が鳴る。
音楽は止めない（音楽には一切触らず、ローカル通知の音だけ鳴らす）。広告なし。買い切り120円で販売予定。
ユーザーは日本語話者。返答は日本語で。

## 構成（Expo SDK 57 + @bacons/apple-targets 5）
- `App.tsx` … 通知の許可リクエストと通知音のテスト再生（5秒後）だけの最小画面
- `assets/sounds/rest.wav` … 約2秒の3回ビープ（expo-notifications の sounds で本体に同梱）
- `targets/widget/` … ウィジェット拡張（Swift, iOS 17+）
  - `StartRestIntent.swift` … ボタンで呼ばれる App Intent。60秒後の通知を予約（同じ識別子で上書き＝押し直しでやり直し）
  - `RestWidget.swift` … 小サイズのウィジェット。カウント中は残り時間を表示
  - `expo-target.config.js`
- `app.json` … bundleIdentifier は仮の `jp.resttimer.app`、`ios.appleTeamId` 設定済み
- `eas.json` … `preview`（internal 配布）と `production` を用意済み

## 現在の状態
- 済: プロジェクト作成、ファイル配置、`app.json` 設定、静的検査（ファイルの有無・プラグイン・SDK）
- 済: EAS に `eas login` 済み（Expo アカウントはユーザーのもの）
- 済: `eas init`（@eastpatsn/rest-timer、ID e389defb-1d36-4f22-b070-841b4ebdd626）
- 済: iPhone 登録、preview ビルド成功（2026-10-03、build 938d36db）。TypeScript は ~5.9.3 に固定（@bacons/apple-targets 内の @expo/require-utils が TS5 を peer 要求し、EAS の npm ci が失敗したため）
- 済: 2026-10-03 作り替え（build 9db9a317、buildNumber 2。preview も autoIncrement に変更＝同じ番号だと iPhone が上書きしないため）
  - 鳴らし方: 通知音 → StartRestIntent（AudioPlaybackIntent + LiveActivityIntent、`targets/widget/_shared/` で本体と拡張の両方にリンク）がアプリ本体を裏で起こし、AVAudioSession .playback + .mixWithOthers で再生。マナーモードでも鳴る。UIBackgroundModes: audio
  - ロック画面の下のボタン（ControlWidget、iOS 18〜）。時間 1〜5分は配置時の設定で選ぶ（押した場で選ぶ UI は iOS に無い）
  - 残り時間はライブアクティビティ（ロック画面・Dynamic Island）。App Group は使わない（入れると Apple 側の登録に対話ログインが要る）
  - ウィジェット（ホーム小・ロック画面 丸/横長）も時間を設定可。拡張の deploymentTarget は 18.0
- 済: 2026-10-03 メニュー方式に変更
  - ロック画面ボタン（ControlWidget）/ウィジェットを押す → ShowRestMenuIntent がライブアクティビティでロック画面にプリセット6個のボタンを出す（iOS のボタンにプルダウンは無いため）
  - プリセット選択 → StartPresetIntent。RestEngine（アプリ本体）が区間ごとにビープ、「停止」（StopRestIntent）まで繰り返す
  - プリセット: 1=2分↔3分、2=5分↔25分（固定）。3〜6はアプリ画面で編集（RN Settings → UserDefaults "restPresets"、JSON [[1],[2,3],...]）
  - buildNumber は app.json で管理（appVersionSource local）。拡張と本体の番号を揃えるため
- 未: 実機確認（ボタンが一覧に出るか／メニュー・繰り返し・停止／マナーモード／音楽が止まらないか）

- Swift コードはビルドで毎回コンパイルされる。ビルドで失敗したらログを読んで直すこと。

## ビルドの方法（2026-10-05〜）
- EAS の無料枠（iOS 月15回）は 10月分を使い切った。以後は GitHub Actions の Mac で `eas build --local` → `eas upload` でインストール用リンクを出す（無料）
- リポジトリ: https://github.com/resttimer-app/rest-timer（公開。組織 resttimer-app、持ち主はユーザーの GitHub アカウント Heastpatsn。販売前に非公開に切り替える予定）
- 実行: `C:\Users\user\tools\gh\bin\gh.exe workflow run ios-build.yml -R resttimer-app/rest-timer`。完了後、ログの "Upload to EAS" にある expo.dev/.../builds/... がインストール用ページ
- buildNumber はワークフローが 100 + 実行番号 に設定する（app.json の値は使わない）
- シークレット EXPO_TOKEN はユーザーが登録済み。鍵の作成・貼り付けは代行しない

## 環境の制約
- ユーザーは Windows（Mac なし）。Windows では `npx expo prebuild`（iOS）が動かない。iOS のビルドと検証は EAS のクラウドビルドで行う。
- 実機確認はユーザーの iPhone。Expo Go では動かない（ウィジェットはネイティブ拡張）。

## 残りの手順（このフォルダで実行）
1. `npx eas-cli init`（プロジェクト作成の質問は y）
2. `npx eas-cli device:create`（Website を選び、出た URL をユーザーが iPhone で開いてプロファイルを入れる）
3. `npx eas-cli build --platform ios --profile preview`（10〜20分。Apple にログインする場面はユーザーが入力）
4. ビルドが通ったら、出力の URL を iPhone で開いてインストール

## ユーザー本人にやらせること（代行しない）
- Apple ID・Expo のパスワードや認証コードの入力
- 支払い・購入、アカウント作成
- 認証情報をチャットや通知に貼らせない

## 実機で確認するリスク
- ウィジェット拡張から予約した通知が実際に鳴るか。拡張のプロセスから通知の許可・音ファイル（`rest.wav`）が見えない場合は、音ファイルを拡張側にも同梱するか、共有の Library/Sounds に置く方法を検討
- 通知音の再生中に音楽が止まる・小さくなる（ダッキング）か。止まるなら設計を見直す
- マナーモード中は鳴らない／集中モードの影響（時間依存の通知で緩和できる可能性）
- ウィジェットのカウント表示が終了時に待機表示へ戻るか

## 次にやること（最小版が動いたら）
1. 秒数をウィジェットごとに設定可能にする（ウィジェットの編集で選ぶ。`AppIntentConfiguration` を使う）
2. 通知音の選択
3. 時間依存の通知への対応
4. アプリ名・アイコン・バンドル ID を確定し、App Store 提出（個人での Apple Developer Program は加入済み）
