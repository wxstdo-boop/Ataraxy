@echo off
chcp 65001 >nul
set PUB_CACHE=X:\pubcache
cd /d X:\ataraxy
echo === CLEAN ===
call C:\Flutter\flutter\bin\flutter.bat clean
echo === PUB GET ===
call C:\Flutter\flutter\bin\flutter.bat pub get
echo === BUILD ===
call C:\Flutter\flutter\bin\flutter.bat build apk --release --split-per-abi --target-platform android-arm64 --no-tree-shake-icons
echo === EXITCODE %errorlevel% ===