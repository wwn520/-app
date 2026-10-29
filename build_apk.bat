@echo off
REM 一键构建安卓 APK（需先在本机安装 Flutter：https://flutter.dev/docs/get-started/install）
cd /d "%~dp0"
echo ============================================
echo  无广告打印机 App —— 一键构建 APK
echo ============================================
echo.
if not exist "android\app\build.gradle" (
  echo [1/5] 生成 iOS/Android 原生工程 (flutter create)...
  flutter create --platforms=ios,android .
)
echo [2/5] 应用权限补丁...
python tools/patch_permissions.py
echo [3/5] 获取依赖...
flutter pub get
if errorlevel 1 (
  echo.
  echo [错误] flutter pub get 失败，请确认已安装 Flutter 并加入 PATH。
  pause
  exit /b 1
)
echo.
echo [4/5] 构建正式版 APK（按 ABI 拆分，体积更小）...
flutter build apk --release --split-per-abi
if errorlevel 1 (
  echo.
  echo [错误] 构建失败，请把上面的报错发给我。
  pause
  exit /b 1
)
echo.
echo ============================================
echo  构建完成！
echo  APK 文件在：build\app\outputs\flutter-apk\
echo  把对应架构的 .apk 传到安卓手机安装即可。
echo ============================================
pause
