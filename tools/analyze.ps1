#requires -Version 5.1
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

# ----------------------------------------------------------------------------
# Ataraxy v0.3 — standalone analyzer smoke-check.
# Прогоняет только `flutter analyze` и пишет полный вывод в BUILD_ANALYZE.txt,
# не запуская сборку APK. Удобно, когда хочется быстро проверить правки
# без 5-минутного gradle.
# Run from C:\Games\ataraxy:
#     powershell -ExecutionPolicy Bypass -File .\tools\analyze.ps1
# ----------------------------------------------------------------------------

Set-Location 'C:\Games\ataraxy'
$analyzeLog = Join-Path (Get-Location) 'BUILD_ANALYZE.txt'

Write-Host "=== flutter analyze -> $analyzeLog ===" -ForegroundColor Cyan
& flutter analyze --no-fatal-warnings --no-fatal-infos > $analyzeLog 2>&1
$analyzeExit = $LASTEXITCODE

if (Test-Path $analyzeLog -and (Get-Item $analyzeLog).Length -gt 0) {
    $lineCount = (Get-Content $analyzeLog | Measure-Object).Count
} else {
    $lineCount = 0
}

if ($analyzeExit -ne 0) {
    Write-Host "`nНайдены ошибки (exit $analyzeExit). Severity-строки (первые 60):" -ForegroundColor Red
    $severityMatches = Select-String -Path $analyzeLog -Pattern '^\s+(error|warning|info)\s+-'
    $severityLines = @($severityMatches | Select-Object -First 60 | ForEach-Object { $_.Line })
    if ($severityLines.Count -gt 0) {
        $severityLines | ForEach-Object { Write-Host $_ }
    } else {
        Write-Host "(severity-строк не нашлось — фолбэк: первые 60 строк всего лога)" -ForegroundColor DarkYellow
        Get-Content $analyzeLog | Select-Object -First 60
    }
    Write-Host ""
    Write-Host "Полный лог: $analyzeLog" -ForegroundColor Yellow
    Write-Host "Скинь мне содержимое этого файла — починю все найденные ошибки." -ForegroundColor Yellow
    exit $analyzeExit
}

Write-Host "`nflutter analyze OK (warnings + info: $lineCount строк в логе)" -ForegroundColor Green
Write-Host "Полный лог: $analyzeLog" -ForegroundColor Green

# Quick summary by severity (real analyzer format: "  error - msg at line N:N")
if (Test-Path $analyzeLog -and (Get-Item $analyzeLog).Length -gt 0) {
    $content = Get-Content $analyzeLog -Raw
    $errCount = ([regex]::Matches($content, '(?m)^\s+error\s+-')).Count
    $warnCount = ([regex]::Matches($content, '(?m)^\s+warning\s+-')).Count
    $infoCount = ([regex]::Matches($content, '(?m)^\s+info\s+-')).Count
    Write-Host ""
    Write-Host "Сводка: errors=$errCount · warnings=$warnCount · info=$infoCount" -ForegroundColor Cyan
}
