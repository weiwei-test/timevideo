#!/usr/bin/env bash
# 时光影视 · 旧壳换皮打包脚本（CI / 本地通用）
# 品牌替换：名称/BundleID/散装图标 ✅   启动屏：用 ibtool 编译新 storyboard 替换 ✅
# 用法: bash scripts/rebrand_ipa.sh [源ipa] [图标svg]
# 依赖: 散装图标替换无需额外依赖；启动屏替换需要 Xcode 的 ibtool（CI runner 自带）
set -euo pipefail

SRC_IPA="${1:-vendor/KanjuAI-1.0.22-0913.ipa}"
ICON_SVG="${2:-Tools/icon.svg}"
APP_NAME_CN="时光影视"
BUNDLE_ID="com.shiguang.timevideo"
OUT_DIR="out_rebrand"
PB=/usr/libexec/PlistBuddy

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/payload_root"

echo "== 1/5 解包旧 ipa =="
unzip -q "$SRC_IPA" -d "$OUT_DIR/payload_root"
APP_DIR=$(find "$OUT_DIR/payload_root/Payload" -maxdepth 1 -name "*.app" | head -1)
if [ "$(basename "$APP_DIR")" != "TimeVideo.app" ]; then
  mv "$APP_DIR" "$OUT_DIR/payload_root/Payload/TimeVideo.app"
fi
APP_DIR="$OUT_DIR/payload_root/Payload/TimeVideo.app"

echo "== 2/5 替换 Info.plist 品牌信息 =="
$PB -c "Set :CFBundleDisplayName $APP_NAME_CN" "$APP_DIR/Info.plist"
$PB -c "Set :CFBundleName $APP_NAME_CN" "$APP_DIR/Info.plist"
$PB -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP_DIR/Info.plist"
$PB -c "Set :H5ShellAppDisplayName $APP_NAME_CN" "$APP_DIR/Info.plist" 2>/dev/null || true
$PB -c "Set :H5ShellAppShortName $APP_NAME_CN" "$APP_DIR/Info.plist" 2>/dev/null || true

render() { sips -s format png -z "$1" "$1" "$ICON_SVG" --out "$2" >/dev/null; }

echo "== 3/5 替换散装 App 图标（iOS 安装时按 CFBundleIconFiles 读取）=="
render 120 "$APP_DIR/AppIconKanjuAI60x60@2x.png"
render 152 "$APP_DIR/AppIconKanjuAI76x76@2x~ipad.png"
sips -g pixelWidth -g pixelHeight "$APP_DIR/AppIconKanjuAI60x60@2x.png" | tail -2

echo "== 4/5 编译品牌启动屏并替换 LaunchScreenKanjuAI.storyboardc =="
LAUNCH_SB="scripts/LaunchScreenKanjuAI.storyboard"
IBTOOL="$(xcrun -f ibtool 2>/dev/null || true)"
NEW_DIR=""
if [ -n "$IBTOOL" ] && [ -f "$LAUNCH_SB" ]; then
  if "$IBTOOL" --compile "$OUT_DIR/LaunchScreenKanjuAI.storyboardc" "$LAUNCH_SB" 2>&1 | tail -2; then
    if [ -d "$OUT_DIR/LaunchScreenKanjuAI.storyboardc" ]; then
      rm -rf "$APP_DIR/Base.lproj/LaunchScreenKanjuAI.storyboardc"
      cp -R "$OUT_DIR/LaunchScreenKanjuAI.storyboardc" "$APP_DIR/Base.lproj/"
      NEW_DIR=$(ls "$APP_DIR/Base.lproj/LaunchScreenKanjuAI.storyboardc")
      echo "启动屏已替换: $NEW_DIR"
    fi
  else
    echo "警告: ibtool 编译失败，保留原启动屏"
  fi
else
  echo "警告: 无 ibtool($([ -z "$IBTOOL" ] && echo missing))或 storyboard 源文件，保留原启动屏"
fi

echo "== 5/5 重新打包 =="
cd "$OUT_DIR/payload_root"
zip -qr "../${APP_NAME_CN}-unsigned-1.0.22.ipa" Payload
cd - >/dev/null
ls -lh "$OUT_DIR/${APP_NAME_CN}-unsigned-1.0.22.ipa"
echo "REBRAND_DONE"
