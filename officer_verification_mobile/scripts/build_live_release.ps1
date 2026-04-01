param(
    [Parameter(Mandatory = $true)]
    [string]$ApiBaseUrl,

    [Parameter(Mandatory = $true)]
    [string]$OfficerId,

    [Parameter(Mandatory = $true)]
    [string]$DeviceKey,

    [Parameter(Mandatory = $true)]
    [string]$DeviceToken
)

$ErrorActionPreference = "Stop"

$projectRoot = Join-Path $PSScriptRoot ".."
Push-Location $projectRoot

try {
    flutter pub get

    flutter build apk --release `
        --dart-define=SAFEARMS_USE_MOCK_FLOW=false `
        --dart-define=SAFEARMS_API_BASE_URL=$ApiBaseUrl `
        --dart-define=SAFEARMS_OFFICER_ID=$OfficerId `
        --dart-define=SAFEARMS_DEVICE_KEY=$DeviceKey `
        --dart-define=SAFEARMS_DEVICE_TOKEN=$DeviceToken

    Write-Host "Release APK ready: build/app/outputs/flutter-apk/app-release.apk"
}
finally {
    Pop-Location
}
