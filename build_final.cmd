@echo off
chcp 65001 >nul
set PUB_CACHE=X:\pubcache
cd /d X:\ataraxy
call C:\Flutter\flutter\bin\flutter.bat build apk --release --split-per-abi --target-platform android-arm64 --no-tree-shake-icons
echo === EXITCODE %errorlevel% ===