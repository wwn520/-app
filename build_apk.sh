#!/usr/bin/env bash
# 一键构建安卓 APK（需先在本机安装 Flutter）
set -e
cd "$(dirname "$0")"
echo "============================================"
echo "  无广告打印机 App —— 一键构建 APK"
echo "============================================"
echo
# 1. 生成缺失的原生工程（首次运行；已存在则跳过）
if [ ! -f "android/app/build.gradle" ]; then
  echo "[1/5] 生成 iOS/Android 原生工程 (flutter create)..."
  flutter create --platforms=ios,android .
fi
# 2. 应用权限补丁（本地网络/mDNS 发现 + 微信系统分享）
echo "[2/5] 应用权限补丁..."
python3 tools/patch_permissions.py
# 3. 获取依赖
echo "[3/5] 获取依赖..."
flutter pub get
# 4. 构建
echo "[4/5] 构建正式版 APK（按 ABI 拆分）..."
flutter build apk --release --split-per-abi
echo
echo "[5/5] 完成"
echo "============================================"
echo "  构建完成！APK 位于 build/app/outputs/flutter-apk/"
echo "  把对应架构的 .apk 传到安卓手机安装即可。"
echo "============================================"
