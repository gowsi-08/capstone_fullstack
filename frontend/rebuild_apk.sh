#!/bin/bash

echo "🔨 Rebuilding FindMyWay APK..."
echo ""

# Navigate to frontend directory
cd "$(dirname "$0")"

# Clean build
echo "🧹 Cleaning build..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build APK
echo "🔨 Building APK..."
flutter build apk --release

# Install new APK
echo "📱 Installing new APK..."
flutter install

echo ""
echo "✅ APK rebuilt and installed!"
echo ""
echo "📱 Check your device:"
echo "- App name should be 'FindMyWay'"
echo "- Icon should show logo.png"
echo ""
