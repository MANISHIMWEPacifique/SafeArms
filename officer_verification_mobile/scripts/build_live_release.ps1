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

$normalizedApiBaseUrl = $ApiBaseUrl.Trim()
if ([string]::IsNullOrWhiteSpace($normalizedApiBaseUrl)) {
    throw "ApiBaseUrl cannot be empty."
}

try {
    $parsedApiUri = [System.Uri]::new($normalizedApiBaseUrl)
} catch {
    throw "ApiBaseUrl must be a valid absolute URL. Received: $ApiBaseUrl"
}

if (-not $parsedApiUri.IsAbsoluteUri -or ($parsedApiUri.Scheme -ne 'https' -and $parsedApiUri.Scheme -ne 'http')) {
    throw "ApiBaseUrl must start with http:// or https://. Received: $ApiBaseUrl"
}

if ($parsedApiUri.Host -eq 'localhost' -or $parsedApiUri.Host -eq '127.0.0.1' -or $parsedApiUri.Host -eq '10.0.2.2') {
    Write-Warning "ApiBaseUrl uses a local host alias. For standalone phones, prefer a stable public URL."
}

if ($normalizedApiBaseUrl.EndsWith('/')) {
    $normalizedApiBaseUrl = $normalizedApiBaseUrl.TrimEnd('/')
}

if (-not $normalizedApiBaseUrl.EndsWith('/api')) {
    $normalizedApiBaseUrl = "$normalizedApiBaseUrl/api"
}

$projectRoot = Join-Path $PSScriptRoot ".."
Push-Location $projectRoot

try {
    flutter pub get

    flutter build apk --release `
        --dart-define=SAFEARMS_USE_MOCK_FLOW=false `
        --dart-define=SAFEARMS_API_BASE_URL=$normalizedApiBaseUrl `
        --dart-define=SAFEARMS_OFFICER_ID=$OfficerId `
        --dart-define=SAFEARMS_DEVICE_KEY=$DeviceKey `
        --dart-define=SAFEARMS_DEVICE_TOKEN=$DeviceToken

    $builtApkPath = Join-Path $projectRoot "build/app/outputs/flutter-apk/app-release.apk"
    if (-not (Test-Path $builtApkPath)) {
        throw "Expected build output not found: $builtApkPath"
    }

    $releaseDir = Join-Path $projectRoot "release"
    New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null

    $releaseApkPath = Join-Path $releaseDir "safearms-officer-verify-v1.0.0+1-live.apk"
    Copy-Item -Path $builtApkPath -Destination $releaseApkPath -Force

    $hash = Get-FileHash -Algorithm SHA256 -Path $releaseApkPath
    $hashLine = "$($hash.Hash.ToLowerInvariant())  $([System.IO.Path]::GetFileName($releaseApkPath))"
    $hashFilePath = Join-Path $releaseDir "SHA256SUMS.txt"
    Set-Content -Path $hashFilePath -Value $hashLine

    Write-Host "Release APK ready: $builtApkPath"
    Write-Host "Upload-ready APK: $releaseApkPath"
    Write-Host "Checksum file: $hashFilePath"
    Write-Host "Using API base URL: $normalizedApiBaseUrl"
}
finally {
    Pop-Location
}
