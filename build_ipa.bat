@echo off
REM 一键构建 iOS IPA（需在已装 Flutter 的电脑上运行，并配置 Xcode 签名）
cd /d "%~dp0"

if not exist "ios\Runner.xcworkspace" (
  echo [1/4] 生成 iOS/Android 原生工程 (flutter create)...
  flutter create --platforms=ios,android .
)
echo [2/4] 应用权限补丁...
python tools/patch_permissions.py
echo [3/4] 获取依赖...
flutter pub get
echo [4/4] 构建 IPA（需先在 Xcode 配置签名）...
flutter build ipa --release
echo IPA 位于 build\ios\ipa\
pause
