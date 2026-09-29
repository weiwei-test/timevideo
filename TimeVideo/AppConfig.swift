import Foundation

/// 站点配置（对应旧版 AppConfigCenter 的承载模型）
struct SiteConfig {
    var appName: String
    var homeURL: String
    var fallbackURLs: [String]
    /// 远程配置下发地址（纯 JSON，格式与 bundled_config.json 相同；按序尝试，首个成功生效）
    var remoteConfigEndpoints: [String]
    var userAgentSuffix: String
    var themeColorHex: String
    var backgroundHex: String

    static let `default` = SiteConfig(
        appName: "时光影视",
        homeURL: "https://kanju.ai",
        fallbackURLs: [
            "https://kanju1.com",
            "https://kanju13.com",
            "https://kanju7.com",
            "https://kanju20.com",
            "https://souju.ai",
        ],
        remoteConfigEndpoints: [],
        userAgentSuffix: "TimeVideo/1.0",
        themeColorHex: "16E05A",
        backgroundHex: "080706"
    )

    /// 启动站点候选：主站 + 备用线路
    var siteCandidates: [String] {
        [homeURL] + fallbackURLs.filter { $0 != homeURL }
    }
}

extension SiteConfig: Codable {
    enum CodingKeys: String, CodingKey {
        case appName, homeURL, fallbackURLs, remoteConfigEndpoints
        case userAgentSuffix, themeColorHex, backgroundHex
    }

    /// 宽松解码：远程配置允许缺省任意字段，缺省用默认值补齐
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SiteConfig.default
        appName = try c.decodeIfPresent(String.self, forKey: .appName) ?? d.appName
        homeURL = try c.decodeIfPresent(String.self, forKey: .homeURL) ?? d.homeURL
        fallbackURLs = try c.decodeIfPresent([String].self, forKey: .fallbackURLs) ?? d.fallbackURLs
        remoteConfigEndpoints = try c.decodeIfPresent([String].self, forKey: .remoteConfigEndpoints) ?? d.remoteConfigEndpoints
        userAgentSuffix = try c.decodeIfPresent(String.self, forKey: .userAgentSuffix) ?? d.userAgentSuffix
        themeColorHex = try c.decodeIfPresent(String.self, forKey: .themeColorHex) ?? d.themeColorHex
        backgroundHex = try c.decodeIfPresent(String.self, forKey: .backgroundHex) ?? d.backgroundHex
    }
}

/// 配置中枢（对应旧版 AppConfigCenter + AppConfigCacheStore）
/// 优先级：磁盘缓存 > Bundle 内置 > 代码默认值；启动后异步刷新远程配置，变更时发通知。
final class AppConfigCenter {

    static let shared = AppConfigCenter()
    private init() {}

    private let cacheFileName = "site_config_cache.json"
    private(set) var current: SiteConfig = .default

    func load(completion: @escaping (SiteConfig) -> Void) {
        if let bundled = loadBundled() { current = bundled }
        if let cached = loadCached() { current = cached }
        completion(current)
        refreshRemote()
    }

    // MARK: - 持久化

    private var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(cacheFileName)
    }

    private func loadBundled() -> SiteConfig? {
        guard let url = Bundle.main.url(forResource: "bundled_config", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SiteConfig.self, from: data)
    }

    private func loadCached() -> SiteConfig? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(SiteConfig.self, from: data)
    }

    private func saveCached(_ config: SiteConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    // MARK: - 远程刷新

    private func refreshRemote() {
        let endpoints = current.remoteConfigEndpoints
        guard !endpoints.isEmpty else { return }
        tryEndpoints(ArraySlice(endpoints))
    }

    private func tryEndpoints(_ endpoints: ArraySlice<String>) {
        guard let first = endpoints.first, let url = URL(string: first) else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self = self else { return }
            if let data = data, let config = try? JSONDecoder().decode(SiteConfig.self, from: data) {
                self.saveCached(config)
                self.current = config
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .siteConfigDidChange, object: config)
                }
            } else {
                self.tryEndpoints(endpoints.dropFirst())
            }
        }.resume()
    }
}
