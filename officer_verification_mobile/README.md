# SafeArms Officer Verification Mobile

Standalone Flutter mobile app for officer-side custody verification in SafeArms.

## Scope

- This is not the full SafeArms mobile app.
- Focus is custody assignment verification flow.
- Supports demo mode and live backend mode.

## Live Mode Requirements

1. Backend is running and reachable from the phone network.
2. Database migrations are applied in order: 013 -> 014 -> 015.
3. Officer has an active enrolled device from commander enrollment.
4. App is built with live dart defines:
   - SAFEARMS_USE_MOCK_FLOW=false
   - SAFEARMS_API_BASE_URL
   - SAFEARMS_OFFICER_ID
   - SAFEARMS_DEVICE_KEY
   - SAFEARMS_DEVICE_TOKEN

Important:
- For physical phones, do not use 10.0.2.2.
- Use a LAN or public backend URL, for example: http://192.168.1.50:5000/api

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
  --dart-define=SAFEARMS_API_BASE_URL=http://192.168.1.50:5000/api \
  --dart-define=SAFEARMS_OFFICER_ID=OFF-001 \
  --dart-define=SAFEARMS_DEVICE_KEY=DVK-XXXX \
  --dart-define=SAFEARMS_DEVICE_TOKEN=YOUR_DEVICE_TOKEN
```

PowerShell one-command alternative:

```powershell
cd officer_verification_mobile
.\scripts\build_live_release.ps1 `
  -ApiBaseUrl "http://192.168.1.50:5000/api" `
  -OfficerId "OFF-001" `
  -DeviceKey "DVK-XXXX" `
  -DeviceToken "YOUR_DEVICE_TOKEN"
```

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
