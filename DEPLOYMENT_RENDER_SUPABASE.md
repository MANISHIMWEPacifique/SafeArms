# SafeArms Stable API Deployment (Render + Supabase)

This guide deploys the existing SafeArms backend to Render with a fixed HTTPS URL and keeps Supabase as the PostgreSQL database.

## Why This Stack

- Minimal code changes for this repository's current Node/Express architecture.
- Fixed HTTPS API URL for frontend and officer mobile app.
- Supabase is already compatible with backend DB config.
- Firebase stays optional for APK distribution only.

## 1. Create Render Service

1. Push this repository to GitHub.
2. In Render, create a **Web Service** from the repository.
3. Use root settings:
   - Root Directory: `backend`
   - Build Command: `npm ci`
   - Start Command: `npm start`
4. Keep Health Check Path as `/health`.

You can also use the included blueprint file: `render.yaml`.

## 2. Configure Environment Variables in Render

Set these values in Render service environment:

- `NODE_ENV=production`
- `DATABASE_URL=<supabase-connection-string>`
- `JWT_SECRET=<strong-random-secret-min-32-chars>`
- `CORS_ORIGIN=<frontend-url-or-comma-list>`
- `API_BASE_URL=<your-render-or-custom-domain>`
- `DB_TIMEZONE=Africa/Kigali`

Notes:
- Use **Supabase transaction/session pooler** connection string if available.
- Keep secrets in Render dashboard, not in repository files.

## 3. Verify Deployment

After first deploy, run:

```bash
cd backend
npm run deploy:smoke -- --base-url https://YOUR-RENDER-SERVICE.onrender.com
```

Optional officer mobile endpoint check:

```bash
cd backend
npm run deploy:smoke -- \
  --base-url https://YOUR-RENDER-SERVICE.onrender.com \
  --officer-id OFF-001 \
  --device-key DVK-XXXX \
  --device-token YOUR_DEVICE_TOKEN
```

## 4. Point Frontend to Fixed API URL

Build frontend with the hosted API base:

```bash
cd frontend
flutter build web --dart-define=API_BASE_URL=https://YOUR-RENDER-SERVICE.onrender.com
```

The frontend app auto-appends `/api` when needed.

## 5. Point Officer Mobile to Fixed API URL

Build mobile release with stable API URL:

```powershell
cd officer_verification_mobile
.\scripts\build_live_release.ps1 `
  -ApiBaseUrl "https://YOUR-RENDER-SERVICE.onrender.com/api" `
  -DiscoveryUrl "https://raw.githubusercontent.com/<org>/<config-repo>/main/discovery/officer_mobile_discovery.json" `
  -OfficerId "OFF-001" `
  -DeviceKey "DVK-XXXX" `
  -DeviceToken "YOUR_DEVICE_TOKEN"
```

The script now:
- Validates API URL format.
- Validates discovery URL format when provided.
- Normalizes `/api` suffix.
- Produces release artifacts in `officer_verification_mobile/release/`.
- Generates `SHA256SUMS.txt` for integrity verification.

## 5.1 Runtime Discovery Operations (Recommended)

Use a stable discovery URL that is hosted separately from the backend URL (for example, a dedicated config repo JSON raw URL).

Example discovery JSON:

```json
{
  "api_base_url": "https://YOUR-RENDER-SERVICE.onrender.com/api",
  "version": "2026.04.04.1",
  "updated_at": "2026-04-04T20:00:00Z"
}
```

Operational flow when backend URL changes:
1. Update only discovery JSON with the new `api_base_url`, `version`, and `updated_at`.
2. Officers reopen app or hit a network failure path.
3. App refreshes discovery and switches to the updated backend URL automatically.

Important:
- Do not host discovery JSON inside the same backend service that may change URL.
- Keep Connection Setup available as emergency manual override.

## 6. Optional Firebase App Distribution

Use Firebase App Distribution only to deliver the APK to testers/operators.

- Backend hosting remains Render.
- Database remains Supabase.

## 7. Operational Notes

- Render free tier may sleep when idle. First request can be slower after inactivity.
- For real-time officer flow with no wake delay, use an always-on Render tier.
- Keep Connection Setup screen available in officer app for emergency override/fallback.
