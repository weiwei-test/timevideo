import UIKit

/// 品牌启动加载页（对应旧版 NativeStartupLoadingView）
final class LoadingViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hex: "080706")

        let accentBar = UIView()
        accentBar.backgroundColor = UIColor(hex: "16E05A")
        accentBar.layer.cornerRadius = 2

        let titleLabel = UILabel()
        titleLabel.text = "时光影视"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)

        let subtitleLabel = UILabel()
        subtitleLabel.text = "正在连接线路…"
        subtitleLabel.textColor = UIColor(white: 1, alpha: 0.55)
        subtitleLabel.font = .systemFont(ofSize: 14)

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.startAnimating()

        [accentBar, titleLabel, subtitleLabel, spinner].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            accentBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 14),
            accentBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            accentBar.widthAnchor.constraint(equalToConstant: 56),
            accentBar.heightAnchor.constraint(equalToConstant: 4),
            subtitleLabel.topAnchor.constraint(equalTo: accentBar.bottomAnchor, constant: 18),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 28),
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}

/// 全部线路不可用时的兜底页（对应旧版 NativeStartupFallbackView）
final class StartupFallbackView: UIView {

    var onRetry: (() -> Void)?

    private let retryButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(hex: "080706")

        let messageLabel = UILabel()
        messageLabel.text = "当前线路暂时不可用\n请检查网络后重试"
        messageLabel.textColor = UIColor(white: 1, alpha: 0.7)
        messageLabel.font = .systemFont(ofSize: 16)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        retryButton.setTitle("重新加载", for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        retryButton.setTitleColor(UIColor(hex: "080706"), for: .normal)
        retryButton.backgroundColor = UIColor(hex: "16E05A")
        retryButton.layer.cornerRadius = 22
        retryButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 36, bottom: 12, right: 36)
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        [messageLabel, retryButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            messageLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            messageLabel.bottomAnchor.constraint(equalTo: centerYAnchor, constant: -16),
            messageLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 32),
            messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32),
            retryButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 28),
            retryButton.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func retryTapped() { onRetry?() }
}
