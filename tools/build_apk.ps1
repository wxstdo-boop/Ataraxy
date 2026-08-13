$ErrorActionPreference = 'Stop'

# Discover the JDK without hard-coding the user's home folder name:
# scan a few well-known JDK layout patterns under the current user profile.
function Find-Jdk {
    $candidates = @()
    if ($env:USERPROFILE) {
        $userRoot = $env:USERPROFILE
        # 1) $USERPROFILE\jdk-21\<version>
        $direct = Join-Path $userRoot 'jdk-21'
        if (Test-Path $direct) {
            $ver = Get-ChildItem -Path $direct -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($ver) { return $ver.FullName }
        }
        # 2) Anything like jdk-* inside user profile
        $perUser = Get-ChildItem -Path $userRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'jdk*' } |
            ForEach-Object {
                Get-ChildItem -Path $_.FullName -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -match 'jdk-\d' } |
                    Select-Object -First 1
            } |
            Where-Object { $_ } |
            Select-Object -First 1
        if ($perUser) { return $perUser.FullName }
    }
    # 3) Common Program Files locations
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
        $hit = Get-ChildItem -Path $p -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'jdk' -or $_.Name -match 'jbr' } |
            ForEach-Object { $_.FullName }
        foreach ($h in $hit) { return $h }
    }
    return $null
}

$jdkHome = Find-Jdk
if (-not $jdkHome) {
    Write-Host "Could not find a JDK. Try installing one (e.g. https://adoptium.net)." -ForegroundColor Red
    exit 1
}

$env:JAVA_HOME = $jdkHome
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
Write-Host ("JAVA_HOME = " + $env:JAVA_HOME) -ForegroundColor Green
& java -version
if ($LASTEXITCODE -ne 0) {
    Write-Host "java -version failed with exit $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}

Set-Location 'C:\Games\ataraxy'
Write-Host "Devices:" -ForegroundColor Green
& flutter devices
Write-Host "Building release APK..." -ForegroundColor Green
& flutter build apk --release
Write-Host ("Build exit: $LASTEXITCODE")
exit $LASTEXITCODE
