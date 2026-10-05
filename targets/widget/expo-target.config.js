/** @type {import('@bacons/apple-targets/app.plugin').ConfigFunction} */
module.exports = (config) => ({
  type: "widget",
  // ロック画面の下のボタン（ControlWidget）は iOS 18 以降
  deploymentTarget: "18.0",
  frameworks: ["SwiftUI", "WidgetKit", "AppIntents", "AVFoundation", "ActivityKit"],
});
