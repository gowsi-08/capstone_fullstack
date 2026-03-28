#!/bin/bash

echo "🎨 Generating app icons from logo.png..."
echo ""

# Navigate to frontend directory
cd "$(dirname "$0")"

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Generate icons
echo "🔨 Generating launcher icons..."
flutter pub run flutter_launcher_icons

echo ""
echo "✅ App icons generated successfully!"
echo ""
echo "📱 Next steps:"
echo "1. Build APK: flutter build apk --release"
echo "2. Install: flutter install"
echo "3. Check app icon in launcher"
echo ""
