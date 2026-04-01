param(
    [string]$ApkPath = "build/app/outputs/flutter-apk/app-release.apk"
)

$ErrorActionPreference = "Stop"

$projectRoot = Join-Path $PSScriptRoot ".."
Push-Location $projectRoot

try {
    if (-not (Test-Path $ApkPath)) {
        throw "APK not found at: $ApkPath"
    }

    adb start-server | Out-Null

    $connectedDevices = (& adb devices) |
        Where-Object { $_ -match "\sdevice$" -and $_ -notmatch "List of devices" }

    if ($connectedDevices.Count -eq 0) {
        throw "No Android device detected. Connect phone and enable USB debugging."
    }

    adb install -r $ApkPath
}
finally {
    Pop-Location
}
