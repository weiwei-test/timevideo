import UIKit

/// 启动引导：品牌加载页 → 读取站点配置 → 进入 Web 容器。
/// 对应旧版 H5Shell 的 AppBootstrap 流程（参照 recovered_kanjuai/objc_meta.txt 中同名类）。
final class AppBootstrap {

    func start(in window: UIWindow) {
        window.tintColor = UIColor(hex: "16E05A")
        window.rootViewController = LoadingViewController()

        AppConfigCenter.shared.load { config in
            DispatchQueue.main.async {
                window.rootViewController = WebViewController(config: config)
            }
        }
    }
}
