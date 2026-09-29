import UIKit
import WebKit

/// 主容器：全屏 WebView 承载"时光影视"前端站点
/// （对应旧版 ViewController + AppWebSessionVault/Manager 的核心职责：
///   会话持久化、站点切换、加载兜底、外链处理）
final class WebViewController: UIViewController {

    private let config: SiteConfig
    private var sites: [URL] = []
    private var siteIndex = 0

    private var webView: WKWebView!
    private var progressView: UIProgressView!
    private var refreshControl: UIRefreshControl!
    private var fallbackView: StartupFallbackView?
    private var progressObserver: NSKeyValueObservation?
    private var configObserver: NSObjectProtocol?

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    init(config: SiteConfig) {
        self.config = config
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        progressObserver?.invalidate()
        if let token = configObserver {
            NotificationCenter.default.removeObserver(token)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hex: config.backgroundHex)
        sites = config.siteCandidates.compactMap { URL(string: $0) }

        setupWebView()
        setupProgressView()
        loadCurrentSite()

        configObserver = NotificationCenter.default.addObserver(
            forName: .siteConfigDidChange, object: nil, queue: .main
        ) { [weak self] note in
            guard let self = self, let newConfig = note.object as? SiteConfig else { return }
            if newConfig.homeURL != self.config.homeURL {
                self.sites = newConfig.siteCandidates.compactMap { URL(string: $0) }
                self.siteIndex = 0
                self.loadCurrentSite()
            }
        }
    }

    // MARK: - UI

    private func setupWebView() {
        let userContent = WKUserContentController()
        userContent.add(WebBridge(), name: WebBridge.handlerName)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContent
        configuration.websiteDataStore = .default()          // Cookie/会话持久化
        configuration.allowsInlineMediaPlayback = true       // H5 播放器可内联播放
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.applicationNameForUserAgent = config.userAgentSuffix
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = UIColor(hex: config.backgroundHex)
        webView.scrollView.backgroundColor = UIColor(hex: config.backgroundHex)
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        self.webView = webView

        let refresh = UIRefreshControl()
        refresh.tintColor = UIColor(hex: config.themeColorHex)
        refresh.addTarget(self, action: #selector(handlePullRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refresh
        self.refreshControl = refresh

        progressObserver = webView.observe(\.estimatedProgress, options: .new) { [weak self] wv, _ in
            guard let self = self else { return }
            let p = Float(wv.estimatedProgress)
            self.progressView.setProgress(p, animated: true)
            self.progressView.isHidden = p >= 1
        }
    }

    private func setupProgressView() {
        let bar = UIProgressView(progressViewStyle: .bar)
        bar.progressTintColor = UIColor(hex: config.themeColorHex)
        bar.trackTintColor = .clear
        bar.isHidden = true
        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 2.5),
        ])
        progressView = bar
    }

    // MARK: - 加载与线路切换

    private func loadCurrentSite() {
        guard siteIndex < sites.count else { showFallback(); return }
        hideFallback()
        webView.load(URLRequest(url: sites[siteIndex], timeoutInterval: 15))
    }

    private func advanceSiteOrFallback() {
        siteIndex += 1
        if siteIndex < sites.count {
            loadCurrentSite()
        } else {
            showFallback()
        }
    }

    private func showFallback() {
        webView.isHidden = true
        guard fallbackView == nil else { return }
        let overlay = StartupFallbackView(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.onRetry = { [weak self] in
            guard let self = self else { return }
            self.siteIndex = 0
            self.webView.isHidden = false
            self.loadCurrentSite()
        }
        view.addSubview(overlay)
        fallbackView = overlay
    }

    private func hideFallback() {
        fallbackView?.removeFromSuperview()
        fallbackView = nil
        webView.isHidden = false
    }

    @objc private func handlePullRefresh() {
        webView.reload()
    }

    private func openExternal(_ url: URL) {
        guard UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            let scheme = url.scheme?.lowercased() ?? ""
            if navigationAction.targetFrame == nil, ["http", "https"].contains(scheme) {
                // target=_blank 在当前容器内打开
                webView.load(URLRequest(url: url))
                decisionHandler(.cancel)
                return
            }
            if !["http", "https", "about", "data", "blob", "file"].contains(scheme) {
                // tel: / mailto: / 各种 App scheme 交给系统
                openExternal(url)
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progressView.isHidden = true
        refreshControl.endRefreshing()
        hideFallback()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        refreshControl.endRefreshing()
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled { return }
        advanceSiteOrFallback()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        refreshControl.endRefreshing()
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled { return }
        if webView.backForwardList.backList.isEmpty {
            advanceSiteOrFallback()
        }
    }
}

// MARK: - WKUIDelegate

extension WebViewController: WKUIDelegate {

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            completionHandler(alert.textFields?.first?.text)
        })
        present(alert, animated: true)
    }
}
