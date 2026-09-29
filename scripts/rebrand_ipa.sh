#!/usr/bin/env bash
# 时光影视 · 旧壳换皮打包脚本（CI / 本地通用，本地需装有 Xcode 才能重建 Assets.car）
# 用法: bash scripts/rebrand_ipa.sh [源ipa] [图标svg]
set -euo pipefail

SRC_IPA="${1:-vendor/KanjuAI-1.0.22-0913.ipa}"
ICON_SVG="${2:-Tools/icon.svg}"
APP_NAME_CN="时光影视"
BUNDLE_ID="com.shiguang.timevideo"
OUT_DIR="out_rebrand"
PB=/usr/libexec/PlistBuddy

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/payload_root" "$OUT_DIR/assets_work"

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

echo "== 3/5 替换散装 App 图标 =="
render 120 "$APP_DIR/AppIconKanjuAI60x60@2x.png"
render 152 "$APP_DIR/AppIconKanjuAI76x76@2x~ipad.png"

echo "== 4/5 尝试重建 Assets.car（App 图标 + 启动图）=="
CAR="$APP_DIR/Assets.car"
CAR_DONE=""
ACTOOL="$(xcrun -f actool 2>/dev/null || true)"
if [ -n "$ACTOOL" ]; then
  pushd "$OUT_DIR/assets_work" >/dev/null
  if [ ! -x acextract ]; then
    if git clone --depth 1 https://github.com/BartoszJanda/acextract acextract-src >/dev/null 2>&1; then
      (cd acextract-src && swift build -c release >/dev/null 2>&1) || true
      BIN=$(find acextract-src/.build -type f -name acextract 2>/dev/null | head -1)
      [ -n "$BIN" ] && cp "$BIN" acextract && chmod +x acextract
    fi
  fi
  if [ -x acextract ]; then
    if ./acextract -i "../../$CAR_REL" -o extracted.xcassets 2>/dev/null; then :; fi
  fi
  popd >/dev/null
fi
# 上面 acextract 路径需要 car 的真实路径，单独再处理一次（更稳妥）
if [ -x "$OUT_DIR/assets_work/acextract" ]; then
  if "$OUT_DIR/assets_work/acextract" -i "$CAR" -o "$OUT_DIR/assets_work/extracted.xcassets" >/dev/null 2>&1; then
    find "$OUT_DIR/assets_work/extracted.xcassets" -maxdepth 1 -type d -name "*.imageset" | while read -r set; do
      name=$(basename "$set")
      case "$name" in
        AppIconKanjuAI*|LaunchIcon*)
          find "$set" -name "*.png" | while read -r p; do
            px=$(sips -g pixelWidth "$p" 2>/dev/null | tail -1 | awk '{print $2}')
            [ -n "$px" ] && render "$px" "$p"
          done
          ;;
      esac
    done
    MINOS=$($PB -c "Print :MinimumOSVersion" "$APP_DIR/Info.plist" 2>/dev/null || echo "13.0")
    mkdir -p "$OUT_DIR/car_out"
    if "$ACTOOL" --compile "$OUT_DIR/car_out" --platform iphoneos --minimum-deployment-target "$MINOS" "$OUT_DIR/assets_work/extracted.xcassets" >/dev/null 2>&1 && [ -f "$OUT_DIR/car_out/Assets.car" ]; then
      cp "$OUT_DIR/car_out/Assets.car" "$CAR"
      find "$OUT_DIR/car_out" -maxdepth 1 -name "AppIcon*.png" -exec cp {} "$APP_DIR/" \; 2>/dev/null || true
      CAR_DONE="yes"
      echo "Assets.car 已重建（图标+启动图已换）"
    fi
  fi
fi
[ -z "$CAR_DONE" ] && echo "警告: Assets.car 未重建，保留原图标资源（散装图标已替换）"

echo "== 5/5 重新打包 =="
cd "$OUT_DIR/payload_root"
zip -qr "../${APP_NAME_CN}-unsigned-1.0.22.ipa" Payload
cd - >/dev/null
ls -lh "$OUT_DIR/${APP_NAME_CN}-unsigned-1.0.22.ipa"
echo "REBRAND_DONE"
