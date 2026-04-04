# SafeArms Officer Verification Mobile

Standalone Flutter mobile app for officer-side custody verification in SafeArms.

## Scope

- This is not the full SafeArms mobile app.
- Focus is custody assignment verification flow.
- Defaults to live backend mode for standalone officer use.
- Supports optional demo mode for UI/testing only.

## Runtime URL Discovery (Option 6)

This app supports runtime backend URL discovery so backend URL changes do not require reinstalling every phone.

How it works:
1. App loads local configuration on startup.
2. App fetches discovery JSON from a stable discovery URL.
3. If discovery contains a newer backend URL, app updates the active API URL automatically.
4. If API calls fail with network errors, app retries once after a fresh discovery pull.
5. Connection Setup remains available for emergency manual recovery.

Current URL resolution order:
1. Discovered URL (if newer than manual override)
2. Manual override URL
3. Last known good URL
4. Build-time default URL

Discovery URL is provided at build time via:
- `SAFEARMS_DISCOVERY_URL`

Discovery JSON contract:

```json
{
  "api_base_url": "https://your-service.onrender.com/api",
  "version": "2026.04.04.1",
  "updated_at": "2026-04-04T20:00:00Z",
  "backup_api_base_url": "https://your-backup-service.onrender.com/api",
  "notes": "Primary SafeArms officer verification API"
}
```

Important:
- Discovery host must be stable and separate from your backend host.
- If discovery is not configured in a build, app still works with manual/build defaults.

## Live Mode Requirements

1. Backend is running and reachable from the phone network.
2. Database migrations are applied in order: 013 -> 014 -> 015.
3. Officer has an active enrolled device from commander enrollment.
4. App credentials are provided either by:
  - In-app Connection Setup screen (recommended for standalone deployment), or
  - Build-time dart defines.

Important:
- For physical phones, do not use 10.0.2.2.
- Use a LAN or public backend URL, for example: https://your-service.onrender.com/api

## Standalone Setup On Device (No PC Connection Required)

1. Install the app APK on the officer phone.
2. Open app -> PIN screen -> Connection Setup.
3. Enter:
  - API Base URL (LAN/public URL reachable from that phone)
  - Officer ID
  - Device Key
  - Device Token
4. Save and continue.

These values are stored on-device and used at runtime, so the app can run independently after installation.

## Optional Demo Mode

If you want non-production mock flow for UI demo/testing:

```bash
flutter run --dart-define=SAFEARMS_USE_MOCK_FLOW=true
```

## Development Run

```bash
cd officer_verification_mobile
flutter pub get
flutter run
```

## One-Time Release Signing Setup

1. Generate a release keystore (Windows PowerShell example):

```powershell
keytool -genkey -v -keystore C:/SafeArms/keys/safearms-release.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 3650 -alias safearms_release
```

2. Create android/key.properties using android/key.properties.example values.
3. Set real values for:
   - storeFile
   - storePassword
   - keyAlias
   - keyPassword

Alternative:
- You can set these environment variables instead of key.properties:
  - SAFEARMS_KEYSTORE_PATH
  - SAFEARMS_KEYSTORE_PASSWORD
  - SAFEARMS_KEY_ALIAS
  - SAFEARMS_KEY_PASSWORD

## Build Live Release APK

```bash
cd officer_verification_mobile
flutter pub get
flutter build apk --release \
  --dart-define=SAFEARMS_USE_MOCK_FLOW=false \
  --dart-define=SAFEARMS_API_BASE_URL=https://your-service.onrender.com/api \
  --dart-define=SAFEARMS_DISCOVERY_URL=https://raw.githubusercontent.com/<org>/<repo>/main/discovery/officer_mobile_discovery.json \
  --dart-define=SAFEARMS_OFFICER_ID=OFF-001 \
  --dart-define=SAFEARMS_DEVICE_KEY=DVK-XXXX \
  --dart-define=SAFEARMS_DEVICE_TOKEN=YOUR_DEVICE_TOKEN
```

PowerShell one-command alternative:

```powershell
cd officer_verification_mobile
.\scripts\build_live_release.ps1 `
  -ApiBaseUrl "https://your-service.onrender.com/api" `
  -DiscoveryUrl "https://raw.githubusercontent.com/<org>/<repo>/main/discovery/officer_mobile_discovery.json" `
  -OfficerId "OFF-001" `
  -DeviceKey "DVK-XXXX" `
  -DeviceToken "YOUR_DEVICE_TOKEN"
```

The script validates the API URL, normalizes the `/api` suffix, and writes a SHA256 checksum file for the upload-ready APK.

## Operator Notes

- In Connection Setup, use `Test Connection` before saving to validate reachability.
- Discovery status is shown in Connection Setup (last sync, discovered URL, and last discovery issue).
- `Use Build Defaults` clears runtime overrides and cached discovery values.

APK output:
- build/app/outputs/flutter-apk/app-release.apk
- release/safearms-officer-verify-v1.0.0+1-live.apk (upload-ready copy)
- release/SHA256SUMS.txt (integrity check)

## Direct Install and Link Distribution Standard

Install to a connected Android phone via ADB:

```powershell
cd officer_verification_mobile
.\scripts\install_release_apk.ps1
```

1. Validate APK on one Android test device first.
2. Upload app-release.apk to your chosen file host (Drive, Dropbox, internal file server).
3. Share download link to testers.
4. Testers install from link and allow app install from browser/files app when prompted.
5. Run one live verification check (pending fetch + approve/reject) after install.

## Optional Firebase App Distribution

Yes, Firebase is supported and is a standard internal distribution path.

Minimum Firebase setup:
1. Create Firebase project.
2. Register Android app package: com.safearms.officerverification.
3. Create Firebase App Distribution app entry.
4. Add tester emails/groups.
5. Upload the same release APK from this project to Firebase App Distribution.

Note:
- Firebase setup requires your Firebase console access and credentials.
- This repository currently does not contain Firebase configuration files.

## Quality Check

```bash
cd officer_verification_mobile
flutter analyze
flutter test
```

## Backend Endpoints Used

- POST /api/officer-verification/mobile/pending
- POST /api/officer-verification/mobile/decision
