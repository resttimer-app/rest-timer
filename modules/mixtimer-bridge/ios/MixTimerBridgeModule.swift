import ExpoModulesCore

/// アプリ画面（JS）から、タイマー本体（RestEngine）を動かす。
/// 本体はアプリのターゲット側（targets/widget/_shared）にあり、このモジュールからは型が見えないので、
/// Objective-C の名前 "MTRestBridge" で呼び出す。
public class MixTimerBridgeModule: Module {
  public func definition() -> ModuleDefinition {
    Name("MixTimerBridge")

    Function("start") { (number: Int, startAt: Int) in
      MixTimerBridgeModule.perform("start:startAt:", NSNumber(value: number), NSNumber(value: startAt))
    }

    Function("stop") {
      MixTimerBridgeModule.perform("stop", nil, nil)
    }
  }

  private static func perform(_ selector: String, _ a: NSNumber?, _ b: NSNumber?) {
    DispatchQueue.main.async {
      guard let bridge = NSClassFromString("MTRestBridge") as? NSObject.Type else { return }
      let sel = NSSelectorFromString(selector)
      guard bridge.responds(to: sel) else { return }
      if let a, let b {
        _ = bridge.perform(sel, with: a, with: b)
      } else {
        _ = bridge.perform(sel)
      }
    }
  }
}
