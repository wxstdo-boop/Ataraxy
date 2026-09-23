@echo off
chcp 65001 >nul

:: Ataraxy APK Build Script for ARM64 (Windows)
:: This script builds the APK for arm64-v8a architecture

echo ==========================================
echo Building Ataraxy APK for ARM64
echo ==========================================

:: Step 1: Get dependencies
echo [1/3] Getting dependencies...
call flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: Failed to get dependencies
    pause
    exit /b 1
)

:: Step 2: Clean previous build
echo [2/3] Cleaning previous build...
call flutter clean

:: Step 3: Build APK for ARM64
echo [3/3] Building APK for arm64-v8a...
call flutter build apk --release --split-per-abi --target-platform android-arm64 --no-tree-shake-icons
if %errorlevel% neq 0 (
    echo ERROR: Build failed
    pause
    exit /b 1
)

echo.
echo ==========================================
echo SUCCESS! APK built in build\app\outputs\flutter-apk\
echo ==========================================

:: Find the APK file
for /r build\app\outputs\flutter-apk %%f in (*arm64-v8a-release.apk) do (
    set APK_PATH=%%f
    goto :found
)
:found

if not defined APK_PATH (
    echo ERROR: APK file not found
    pause
    exit /b 1
)

echo APK location: %APK_PATH%

:: Try to install on connected device
echo.
echo Looking for connected Android devices...
for /f "tokens=1" %%d in ('adb devices ^| findstr device') do (
    set DEVICE_ID=%%d
    echo Found device: %%d
    echo Installing APK...
    call adb -s %%d install -r "%APK_PATH%"
    if %errorlevel% equ 0 (
        echo APK installed successfully on %%d
    ) else (
        echo Failed to install on %%d
    )
)

echo.
echo If no device was found, manually install:
echo   adb install -r "%APK_PATH%"
pause
