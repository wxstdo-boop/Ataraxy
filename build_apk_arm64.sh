#!/bin/bash

# Ataraxy APK Build Script for ARM64
# This script builds the APK for arm64-v8a architecture

echo "=========================================="
echo "Building Ataraxy APK for ARM64"
echo "=========================================="

# Step 1: Get dependencies
echo "[1/3] Getting dependencies..."
flutter pub get
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to get dependencies"
    exit 1
fi

# Step 2: Clean previous build
echo "[2/3] Cleaning previous build..."
flutter clean

# Step 3: Build APK for ARM64
echo "[3/3] Building APK for arm64-v8a..."
flutter build apk \
    --release \
    --split-per-abi \
    --target-platform android-arm64 \
    --no-tree-shake-icons

if [ $? -ne 0 ]; then
    echo "ERROR: Build failed"
    exit 1
fi

# Find the APK file
APK_PATH=$(find build/app/outputs/flutter-apk -name "*arm64-v8a-release.apk" | head -1)

if [ -z "$APK_PATH" ]; then
    echo "ERROR: APK file not found"
    exit 1
fi

echo ""
echo "=========================================="
echo "SUCCESS! APK built at:"
echo "  $APK_PATH"
echo "=========================================="

# Try to install on connected device
echo ""
echo "Looking for connected Android devices..."
adb devices | grep -E '^[0-9A-Za-z]+\s+device$' | while read -r device; do
    DEVICE_ID=$(echo $device | awk '{print $1}')
    echo "Found device: $DEVICE_ID"
    echo "Installing APK..."
    adb -s $DEVICE_ID install -r "$APK_PATH"
    if [ $? -eq 0 ]; then
        echo "APK installed successfully on $DEVICE_ID"
    else
        echo "Failed to install on $DEVICE_ID"
    fi
done

echo ""
echo "If no device was found, manually install:"
echo "  adb install -r $APK_PATH"
