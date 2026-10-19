# App Store 掲載情報（日本語）下書き

App Store Connect の各欄にそのまま貼る想定。文字数の上限を括弧に書いた。

## 名前（30）
MixTimer

## サブタイトル（30）
音楽を止めずに鳴る、くり返しタイマー

## プロモーションテキスト（170）
音楽やポッドキャストを聴いたまま、決めた時間で「ピッ」。ロック画面のボタンを長押しするだけで、筋トレのレストも、勉強や家事のポモドーロも、止めるまでくり返します。

## 説明（4000）
音楽を聴きながら使える、くり返しタイマーです。
鳴るのは短い合図の音だけ。再生中の音楽やポッドキャストは止まらず、小さくもなりません。

■ こんな人に
・筋トレのセット間レストを、音楽を流したまま計りたい
・25分集中＋5分休憩のポモドーロで、勉強や家事を進めたい
・タイマーのたびにスマホを開くのが面倒

■ 使い方
1. アプリで「プリセット」を作る（例: 2分→3分、25分→5分）
2. ロック画面の下のボタンを MixTimer に変える
3. ボタンを長押しして、プリセットを選ぶだけ
あとは区間が終わるたびに合図が鳴り、「停止」を押すまでくり返します。

■ 特長
・音楽を止めない：合図の音は音楽と重ねて鳴らします
・マナーモードでも鳴る：消音スイッチがオンでも合図が聞こえます
・くり返し：区間を最大5つまで並べ、止めるまで順番にくり返します（例: 5分→10分→25分）
・途中から始める：3つの区間のうち2つ目から、のように開始位置を選べます
・ロック画面で完結：残り時間はロック画面と Dynamic Island に表示。ロック解除なしで開始・停止できます
・プリセット6つ：30秒刻み（5分まで）、1分刻み（20分まで）、30分・45分・60分から選べます
・広告なし、アカウント登録なし、データの送信なし

■ ご注意
・ロック画面のボタンは iOS 18 以降で使えます
・タイマーの動作中は、合図を鳴らすためにアプリがバックグラウンドで動き続けます。使い終わったら「停止」を押してください

## キーワード（100、カンマ区切り・スペースなし）
筋トレ,レスト,ポモドーロ,勉強,集中,家事,ワークアウト,休憩,ジム,HIIT,タバタ,音楽,ロック画面,繰り返し,インターバル

## カテゴリ
- プライマリ: ヘルスケア／フィットネス
- セカンダリ: 仕事効率化

## 年齢制限
4+（該当する内容なし）

## 価格
買い切り。120円前後の価格帯（App Store Connect の価格一覧で、近いものを選ぶ）

## サポートURL
https://resttimer-app.github.io/rest-timer/

## プライバシーポリシーURL
https://resttimer-app.github.io/rest-timer/privacy.html

## App のプライバシー（App Store Connect の質問への答え）
「データを収集していない」。通信をしない。プリセットと動作の記録は端末の中だけに保存。

## 審査メモ（App Review Information → Notes。英語）
MixTimer is a repeating timer that plays a short beep at the end of each user-defined segment (e.g. 2 min → 3 min, repeated until the user taps Stop), while the user keeps listening to music from another app.

Background audio (UIBackgroundModes: audio) is used for the core feature: the app must play the audible beep at an exact time while it is in the background and the device is locked, including when the ring/silent switch is on. The audio session uses .playback with .mixWithOthers so the user's music is never paused or ducked. Audio playback only runs while a timer is active and stops completely when the user taps Stop.

How to test:
1. Open the app. Presets 1 (2 min ↔ 3 min) and 2 (5 min ↔ 25 min) exist by default; tap a time to change it, or "+" to add a segment. For a quick test, set a preset to 30 sec.
2. Lock the device. Long-press the lock screen and tap Customize → Lock Screen, replace a bottom control with "MixTimer".
3. Long-press that control. A Live Activity menu appears on the Lock Screen; tap a preset, then the segment to start from.
4. A beep plays at the end of every segment and the timer repeats until you tap the red Stop button in the Live Activity.
No account or login is required.
