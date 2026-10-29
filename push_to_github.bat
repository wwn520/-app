@echo off
REM 一键把打印机 App 代码提交到本地 git 仓库（推送到 GitHub 由你完成）
cd /d "%~dp0"

if not exist ".git" (
  git init
  echo Git 仓库已初始化。
)

git add .
git commit -m "打印机 App：局域网 mDNS+IPP 直连打印、相册/拍照/微信导入、身份证本地识别拼版（无广告）"
echo.
echo ============================================================
echo  代码已提交到本地仓库。接下来你只需做两件事（一次性）：
echo.
echo  1) 打开 https://github.com 新建一个空仓库（不要勾选 README/license）
echo  2) 复制仓库地址（形如 https://github.com/你的用户名/仓库名.git），
echo     在本窗口继续运行下面两行（把地址换成你刚复制的）：
echo.
echo        git remote add origin 你的仓库地址
echo        git push -u origin main
echo.
echo  推送时会让你登录 GitHub（用网页令牌 Personal Access Token 或个人密码）。
echo  推送成功后，进入仓库页面的 Actions 标签，等构建跑完，
echo  在 Artifacts 里下载 app-release-apk 即可（.apk 文件）。
echo ============================================================
pause
