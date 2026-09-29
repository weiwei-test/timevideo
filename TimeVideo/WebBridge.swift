import WebKit
import UIKit

/// H5 ↔ Native 桥（旧版 AppNativeAuthCoordinator / ScriptMessageProxy 的精简实现）
///
/// H5 调用示例：
///   window.webkit.messageHandlers.timevideo.postMessage({action:"appInfo", callback:"onAppInfo"})
///   原生回调：window.onAppInfo({...json})
final class WebBridge: NSObject, WKScriptMessageHandler {

    static let handlerName = "timevideo"

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }

        switch action {
        case "appInfo":
            let info: [String: Any] = [
                "appName": "时光影视",
                "bundleId": Bundle.main.bundleIdentifier ?? "",
                "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
                "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "",
                "platform": "ios",
                "systemVersion": UIDevice.current.systemVersion,
            ]
            reply(to: message, callback: body["callback"], payload: info)

        case "openExternal":
            if let raw = body["url"] as? String, let url = URL(string: raw),
               UIApplication.shared.canOpenURL(url) {
                DispatchQueue.main.async { UIApplication.shared.open(url) }
            }

        case "keepScreenOn":
            if let on = body["enabled"] as? Bool {
                DispatchQueue.main.async { UIApplication.shared.isIdleTimerDisabled = on }
            }

        case "copyText":
            if let text = body["text"] as? String {
                UIPasteboard.general.string = text
            }

        default:
            break
        }
    }

    /// 把结果回调给 H5：(callback)(payloadJson)；callback 仅允许标识符/点号路径，防注入
    private func reply(to message: WKScriptMessage, callback: Any?, payload: [String: Any]) {
        guard let cb = (callback as? String),
              cb.range(of: "^[A-Za-z_$][A-Za-z0-9_$.]*$", options: .regularExpression) != nil,
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8),
              let webView = message.webView else { return }
        let js = "try { (\(cb))(\(json)); } catch (e) {}"
        DispatchQueue.main.async {
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}
