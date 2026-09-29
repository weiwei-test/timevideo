import UIKit

extension UIColor {
    /// 用 "16E05A" 这类十六进制字符串创建颜色
    convenience init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(red: CGFloat((value >> 16) & 0xFF) / 255.0,
                  green: CGFloat((value >> 8) & 0xFF) / 255.0,
                  blue: CGFloat(value & 0xFF) / 255.0,
                  alpha: 1)
    }
}

extension Notification.Name {
    /// 远程配置刷新成功（object 为新的 SiteConfig）
    static let siteConfigDidChange = Notification.Name("SiteConfigDidChangeNotification")
}
