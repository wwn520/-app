#!/usr/bin/env bash
# 一键构建 iOS IPA（需在 Mac 上运行，并已配置 Xcode 签名）
set -e
cd "$(dirname "$0")"

# 1. 生成缺失的原生工程（首次运行；已存在则跳过）
if [ ! -d "ios/Runner.xcworkspace" ]; then
  echo "[1/4] 生成 iOS/Android 原生工程 (flutter create)..."
  flutter create --platforms=ios,android .
fi

# 2. 应用权限补丁（本地网络/mDNS 发现 + 微信系统分享）
echo "[2/4] 应用权限补丁..."
python3 tools/patch_permissions.py

# 3. 获取依赖
echo "[3/4] 获取依赖..."
flutter pub get

# 4. 构建 IPA（需已在 Xcode 配置开发者团队/签名）
echo "[4/4] 构建 IPA..."
flutter build ipa --release
echo
echo "构建完成！IPA 位于 build/ios/ipa/，用 TestFlight 或 Xcode 装到 iPhone。"
