# 时光影视（TimeVideo）— iOS 重建工程

> 基于 `recovered_kanjuai/` 中逆向恢复的 H5Shell 架构重建，全新品牌"时光影视"。
> Bundle ID：`com.shiguang.timevideo` ｜ 部署目标：iOS 16+ ｜ Swift 5

---

## 快速开始

1. 用 **Xcode 16+** 打开 `TimeVideo.xcodeproj`
2. 选中 target → *Signing & Capabilities* 填入你的 **Development Team**
3. 选真机或模拟器，⌘R 运行

首次启动流程：品牌启动页 → 读取站点配置 → WebView 加载主站（kanju.ai），失败自动轮换备用线路，全部失败显示兜底页（可一键重试）。

> ⚠️ 注意：当前这台 Mac 只有命令行工具没装 Xcode，本工程已做 swiftc 语法校验（8 个文件全部通过 parse），**首次完整构建请在有 Xcode 的机器上跑一遍**。

## 工程结构

```
timevideo/
├── TimeVideo.xcodeproj/          手工编写的工程文件（objectVersion 56，Xcode 14+ 可读）
├── TimeVideo/
│   ├── AppDelegate.swift         入口；AVAudioSession 后台音频（对应旧版 UIBackgroundModes=audio）
│   ├── SceneDelegate.swift       窗口场景
│   ├── AppBootstrap.swift        启动引导：加载页 → 配置 → 主容器（对应旧版 AppBootstrap）
│   ├── AppConfig.swift           SiteConfig 模型 + AppConfigCenter 配置中枢
│   ├── WebViewController.swift   主容器：WKWebView 全屏 + 进度条 + 下拉刷新 + 线路切换 + 兜底
│   ├── WebBridge.swift           H5↔Native 桥（window.webkit.messageHandlers.timevideo）
│   ├── Views.swift               LoadingViewController / StartupFallbackView
│   ├── Utils.swift               UIColor(hex:)、通知定义
│   ├── Resources/
│   │   ├── bundled_config.json   ★ 站点配置（改这里换站/加线路/开远程下发）
│   │   └── hls.min.js            恢复自原 ipa（预留给未来的原生 HLS 回退页）
│   ├── Assets.xcassets/          AppIcon（单张 1024，Xcode 自动生成其余尺寸）+ AccentColor
│   ├── LaunchScreen.storyboard   深色品牌启动页
│   └── Info.plist
└── Tools/icon.svg                图标源稿（改完用 sips 重新渲染，命令见"换图标"）
```

## 站点配置（bundled_config.json）

| 字段 | 说明 |
|---|---|
| `homeURL` | 主站，当前 `https://kanju.ai` |
| `fallbackURLs` | 备用线路池，主站失败按序尝试 |
| `remoteConfigEndpoints` | 远程配置下发地址（**纯 JSON**，格式同本文件；App 启动后异步拉取，成功即缓存并在主站变化时热切换）。多地址按序尝试，全部失败静默沿用本地配置 |
| `userAgentSuffix` | UA 追加串（默认 `TimeVideo/1.0`，服务端可据此识别壳） |
| `themeColorHex` / `backgroundHex` | 品牌色/背景色 |

HX5 端识别原生能力：UA 含 `TimeVideo/`，可调用 `window.webkit.messageHandlers.timevideo.postMessage({action, callback})`：

| action | 参数 | 说明 |
|---|---|---|
| `appInfo` | `callback` | 回调 `{appName, bundleId, version, build, platform, systemVersion}` |
| `openExternal` | `url` | 交给系统打开外部 scheme/链接 |
| `keepScreenOn` | `enabled` | 播放时保持常亮 |
| `copyText` | `text` | 写剪贴板 |

## 换图标

```bash
sips -s format png -z 1024 1024 Tools/icon.svg \
     --out TimeVideo/Assets.xcassets/AppIcon.appiconset/icon-1024.png
```

## 与旧版 H5Shell 的功能差距路线图

本工程恢复的是"壳的核心骨架"。旧版原生能力按优先级建议逐步补回（旧版每个类的方法签名都在 `recovered_kanjuai/classes_index.txt`，可作为重写蓝本）：

- [ ] **原生播放器桥**（NativePlaybackBridgePlayerViewController 族：AVControls/弹幕/SleepTimer/手势/进度）
- [ ] **本地代理播流**（LocalProxyServer + MP4 HEVC Range 修补，解决防盗链/HEVC 兼容）
- [ ] **HLS/MP4 预热管线**（双路预热 + 下一集预取）
- [ ] **下载体系**（HLS 包装下载 + SQLite + 离线弹幕 + 下载管理 UI）
- [ ] **设备会话/JWT 账号同步**（AppDeviceSession*/AppNativeProjectJwt* 族）
- [ ] **扫码**（NativeQRScannerViewController）
- [ ] **DoH 抗污染**（DoHResolver + DNSPrefetchService）
- [ ] **诊断面板**（AppDiagnosticsCenter）

## 与恢复资料的关系

- 架构蓝本：`recovered_kanjuai/RECOVERY_REPORT.md`、`classes_index.txt`（822 条类→方法签名）
- 前端站点镜像：`recovered_kanjuai/site/`（改域名部署后即新 App 的 homeURL）
- 原 ipa 全量解包：`recovered_kanjuai/Payload/`
