@echo off
echo 🎨 Generating app icons from logo.png...
echo.

REM Navigate to frontend directory
cd /d "%~dp0"

REM Get dependencies
echo 📦 Getting dependencies...
call flutter pub get

REM Generate icons
echo 🔨 Generating launcher icons...
call flutter pub run flutter_launcher_icons

echo.
echo ✅ App icons generated successfully!
echo.
echo 📱 Next steps:
echo 1. Build APK: flutter build apk --release
echo 2. Install: flutter install
echo 3. Check app icon in launcher
echo.
pause
