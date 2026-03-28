@echo off
echo 🔨 Rebuilding FindMyWay APK...
echo.

REM Navigate to frontend directory
cd /d "%~dp0"

REM Clean build
echo 🧹 Cleaning build...
call flutter clean

REM Get dependencies
echo 📦 Getting dependencies...
call flutter pub get

REM Build APK
echo 🔨 Building APK...
call flutter build apk --release

REM Install new APK
echo 📱 Installing new APK...
call flutter install

echo.
echo ✅ APK rebuilt and installed!
echo.
echo 📱 Check your device:
echo - App name should be "FindMyWay"
echo - Icon should show logo.png
echo.
pause
