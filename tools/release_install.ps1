#requires -Version 5.1
[CmdletBinding()]
param(
    # Bypass the flutter analyze smoke-check. Use this only AFTER you've
    # already triaged the BUILD_ANALYZE.txt output and confirmed there are
    # only style nits. Hard errors still won't be caught.
    [switch]$SkipAnalyze
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

# ----------------------------------------------------------------------------
# Ataraxy v0.3 — release build + install, in one shot.
# Run from C:\Games\ataraxy:
#     powershell -ExecutionPolicy Bypass -File .\tools\release_install.ps1
# Add -SkipAnalyze to bypass the analyzer smoke-check.
# ----------------------------------------------------------------------------

# --- 1. Auto-detect JDK (same algorithm as tools\build_apk.ps1) -------
function Find-Jdk {
    if ($env:USERPROFILE) {
        $userRoot = $env:USERPROFILE
        $direct = Join-Path $userRoot 'jdk-21'
        if (Test-Path $direct) {
            $ver = Get-ChildItem -Path $direct -Directory -EA SilentlyContinue | Select-Object -First 1
            if ($ver) { return $ver.FullName }
        }
        $perUser = Get-ChildItem -Path $userRoot -Directory -EA SilentlyContinue |
            Where-Object { $_.Name -like 'jdk*' } |
            ForEach-Object {
                Get-ChildItem -Path $_.FullName -Directory -EA SilentlyContinue |
                    Where-Object { $_.Name -match 'jdk-\d' } |
                    Select-Object -First 1
            } |
            Where-Object { $_ } |
            Select-Object -First 1
        if ($perUser) { return $perUser.FullName }
    }
    $prog = @(
        'C:\Program Files\Java',
        'C:\Program Files\Eclipse Adoptium',
        'C:\Program Files\OpenJDK',
        'C:\Android\jdk',
        'C:\Program Files\Android Studio\jbr',
        'C:\Program Files\Android Studio\jre'
    )
    foreach ($p in $prog) {
        if (-not (Test-Path $p)) { continue }
        $hit = Get-ChildItem -Path $p -Directory -EA SilentlyContinue |
            Where-Object { $_.Name -match 'jdk' -or $_.Name -match 'jbr' } |
            ForEach-Object { $_.FullName }
        foreach ($h in $hit) { return $h }
    }
    return $null
}

$jdkHome = Find-Jdk
if (-not $jdkHome) {
    Write-Host "JDK не найден автоматически. Поставь Adoptium Temurin 21 (https://adoptium.net) и запусти скрипт снова." -ForegroundColor Red
    exit 1
}
$env:JAVA_HOME = $jdkHome
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
Write-Host "JAVA_HOME = $env:JAVA_HOME" -ForegroundColor Green
& java -version
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# --- 2. Move into the project -----------------------------------------
Set-Location 'C:\Games\ataraxy'
Write-Host "Project: $(Get-Location)" -ForegroundColor Green
$analyzeLog = Join-Path (Get-Location) 'BUILD_ANALYZE.txt'

# --- 3. Fetch dependencies -------------------------------------------
Write-Host "`n=== [1/5] flutter pub get ===" -ForegroundColor Cyan
& flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "flutter pub get провалился (exit $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}

# --- 4. Static analysis smoke-check ----------------------------------
# Полный вывод логируется в BUILD_ANALYZE.txt рядом с проектом.
# Hard errors (severity=error) стопорят сборку — дальше не идём, чтобы не
# выкатить сломанный APK. Warnings + info пишутся в лог, но не фатальны.
Write-Host "`n=== [2/5] flutter analyze (errors halt; warnings+info -> $analyzeLog) ===" -ForegroundColor Cyan
if (-not $SkipAnalyze) {
    & flutter analyze --no-fatal-warnings --no-fatal-infos > $analyzeLog 2>&1
    $analyzeExit = $LASTEXITCODE
    if (Test-Path $analyzeLog -and (Get-Item $analyzeLog).Length -gt 0) {
        $lineCount = (Get-Content $analyzeLog | Measure-Object).Count
    } else {
        $lineCount = 0
    }
    if ($analyzeExit -ne 0) {
        Write-Host "flutter analyze нашёл ошибки (exit $analyzeExit). Первые 60 строк лога:" -ForegroundColor Red
        Get-Content $analyzeLog | Select-Object -First 60
        Write-Host ""
        Write-Host "Полный лог: $analyzeLog" -ForegroundColor Yellow
        Write-Host "Скинь мне содержимое этого файла — починю все найденные ошибки." -ForegroundColor Yellow
        Write-Host "Если хочешь собрать APK на свой риск (например, чтобы поиграть с UI), запусти:" -ForegroundColor Yellow
        Write-Host "    powershell -File .\tools\release_install.ps1 -SkipAnalyze" -ForegroundColor Yellow
        exit $analyzeExit
    }
    Write-Host "flutter analyze OK — $lineCount строк (warnings+info) в `"$analyzeLog`"" -ForegroundColor Green
}
else {
    Write-Host "Пропущено по флагу -SkipAnalyze. Лог `"$analyzeLog`" НЕ обновлён." -ForegroundColor DarkYellow
}

# --- 5. Regenerate launcher icons (assets/ataraxy.png -> mipmap) -----
Write-Host "`n=== [3/5] Регенерация иконок лаунчера ===" -ForegroundColor Cyan
# flutter_launcher_icons is already declared in pubspec.yaml (image_path: assets/ataraxy.png)
& dart run flutter_launcher_icons
if ($LASTEXITCODE -ne 0) {
    Write-Host "dart run flutter_launcher_icons провалился (exit $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}

# --- 6. Build release APK --------------------------------------------
Write-Host "`n=== [4/5] Сборка release APK (flutter build apk --release) ===" -ForegroundColor Cyan
& flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "flutter build apk --release провалился (exit $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}

$apk = "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $apk)) {
    Write-Host "APK не найден после сборки: $apk" -ForegroundColor Red
    exit 1
}
$sizeMb = [math]::Round((Get-Item $apk).Length / 1MB, 1)
Write-Host "`nAPK готов: $apk ($sizeMb МБ)" -ForegroundColor Green

# --- 7. Install via adb ------------------------------------------------
Write-Host "`n=== [5/5] Установка через adb ===" -ForegroundColor Cyan
& adb devices
$devs = (& adb devices) | Where-Object { $_ -match '\sdevice$' }
if ($devs.Count -eq 0) {
    Write-Host "Телефон не виден через adb." -ForegroundColor Yellow
    Write-Host "Включи отладку по USB, подключи кабель и запусти скрипт ещё раз," -ForegroundColor Yellow
    Write-Host "либо ставь вручную:" -ForegroundColor Yellow
    Write-Host "    adb install -r `"$apk`"" -ForegroundColor Yellow
    exit 0
}

Write-Host "Устанавливаю на: $($devs -join ', ')" -ForegroundColor Cyan
$installOutput = (& adb install -r $apk 2>&1)
$errOut = $installOutput -join "`n"
if ($LASTEXITCODE -ne 0) {
    Write-Host "adb install провалился (exit $LASTEXITCODE)." -ForegroundColor Red
    Write-Host ""
    Write-Host $errOut -ForegroundColor DarkYellow
    if ($errOut -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE') {
        Write-Host ""
        Write-Host "Похоже, на телефоне уже стоит Ataraxy, подписанная другим debug-keystore-ом" -ForegroundColor Yellow
        Write-Host "(например, ты переустановил Android Studio или переезжал на новый ПК)." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Решение:" -ForegroundColor Yellow
        Write-Host "    adb uninstall com.ataraxy.dream_journal" -ForegroundColor Yellow
        Write-Host "затем запусти этот скрипт снова." -ForegroundColor Yellow
    }
    elseif ($errOut -match 'INSTALL_FAILED_VERSION_DOWNGRADE') {
        Write-Host ""
        Write-Host "На телефоне стоит более новая версия Ataraxy. Решение:" -ForegroundColor Yellow
        Write-Host "    adb uninstall com.ataraxy.dream_journal" -ForegroundColor Yellow
        Write-Host "затем запусти этот скрипт снова." -ForegroundColor Yellow
    }
    elseif ($errOut -match 'INSTALL_FAILED_INSUFFICIENT_STORAGE') {
        Write-Host ""
        Write-Host "На телефоне кончилась память. Удали старые приложения или фото, затем запусти скрипт снова." -ForegroundColor Yellow
    }
    exit $LASTEXITCODE
}
if ($installOutput) { Write-Host $installOutput -ForegroundColor Green }

Write-Host "`n=== Готово — v0.3 установлен на телефон! ===" -ForegroundColor Green
Write-Host "Лог analyzer-а лежит здесь: $analyzeLog" -ForegroundColor DarkGray
Write-Host "Открой приложение на телефоне и проверь:" -ForegroundColor Cyan
Write-Host "  * Настройки -> О приложении -> подзаголовок должен быть `FOSS 0.3`" -ForegroundColor White
Write-Host "  * Карточка `Патч-ноуты` раскрывается с 8 пунктами" -ForegroundColor White
Write-Host "  * Баннер `Steqtoq` показывает снек-бар `Steqtoq - Скоро`" -ForegroundColor White
Write-Host "  * Видео в Избранном: шкала времени пульсирует" -ForegroundColor White
Write-Host "  * Вкладка `Все` на главном не показывает заметки" -ForegroundColor White
