# CloudKit Setup and Verification Guide

This guide documents how to enable CloudKit for Roomies across the backend and iOS app, which keys and entitlements are required, and how to verify locally.

> Local-first remains fully supported. CloudKit is optional and can be enabled later without breaking local functionality.

---

## Prerequisites

- Apple Developer Program (paid) account
- A CloudKit container created in Apple Developer → Identifiers → iCloud Containers
- A CloudKit Web Services key (Key ID + Private Key PEM) if you plan to use server-to-server Web Services
- Node.js 18+ and npm 9+
- Xcode 15+

---

## Backend Configuration

Backend CloudKit behavior is controlled via environment variables.

- **CLOUDKIT_ENABLED** — set to `true` to activate CloudKit logic
- **CLOUDKIT_CONTAINER_ID** — your CloudKit container, e.g. `iCloud.de.roomies.HouseholdApp`

Web Services (server-to-server) optional but recommended for production:

- **CLOUDKIT_USE_WEB_SERVICES** — `true` to use signed Web Services requests
- **CLOUDKIT_ENV** — `development` or `production`
- **CLOUDKIT_KEY_ID** — the Key ID from Apple Developer
- **CLOUDKIT_PRIVATE_KEY** — the PEM private key contents. Use a single-line string with `\n` escapes when stored in `.env`.
- **CLOUDKIT_API_TOKEN** — optional, for other auth scenarios

Example `.env` (or `.env.secure`):

```
# Core
NODE_ENV=development
PORT=3000
DATABASE_URL=postgresql://localhost:5432/roomies_dev

# CloudKit
CLOUDKIT_ENABLED=true
CLOUDKIT_CONTAINER_ID=iCloud.de.roomies.HouseholdApp

# Web Services (optional)
CLOUDKIT_USE_WEB_SERVICES=true
CLOUDKIT_ENV=development
CLOUDKIT_KEY_ID=YOUR_KEY_ID
CLOUDKIT_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIIEv...\n-----END PRIVATE KEY-----\n"
```

Security note:
- Do not commit `.env` files. For extra safety, put secrets in `.env.secure` (loaded automatically if present) which should also be git-ignored.

---

## Verifying Backend CloudKit

1) Install deps

```
cd roomies-backend
npm ci
```

2) Run the CloudKit unit test (validates signing and enablement)

```
npm test -- --runTestsByPath tests/services/CloudKitService.web.test.ts
```

3) Start the dev server with CloudKit enabled

```
# Replace KEY_ID and PRIVATE_KEY with your real values
CLOUDKIT_ENABLED=true \
CLOUDKIT_USE_WEB_SERVICES=true \
CLOUDKIT_ENV=development \
CLOUDKIT_CONTAINER_ID=iCloud.de.roomies.HouseholdApp \
CLOUDKIT_KEY_ID=YOUR_KEY_ID \
CLOUDKIT_PRIVATE_KEY="$(cat /path/to/your/private_key.pem)" \
npm run dev
```

4) Check health and cloud status

- Health: `GET http://localhost:3000/health`
- Cloud status: `GET http://localhost:3000/api/cloud/status`

You should see JSON like:

```
{
  "success": true,
  "cloud": {
    "enabled": true,
    "available": true,
    "lastSync": null,
    "error": null
  }
}
```

Notes:
- If `available` is `false`, the service is enabled but not fully configured (e.g., missing key/container). Backend will still run with safe fallbacks.

---

## iOS App Configuration

Already configured:
- Entitlements set in `HouseholdApp.entitlements`:
  - `iCloud` services with `CloudKit` enabled
  - Container: `iCloud.de.roomies.HouseholdApp`
- App reads runtime flags from backend to toggle CloudKit usage automatically.

Runtime toggles (Info.plist defaults):
- `CloudSyncEnabled` (Bool) default: false
- `CloudSyncAvailable` (Bool) default: false

At runtime, `NetworkManager` calls backend `GET /events/status` and updates:
- `CloudRuntime.shared.setCloud(enabled: cloud.enabled, available: cloud.available)`

Manual override for local testing (optional):
- Temporarily set `CloudSyncEnabled` and `CloudSyncAvailable` to `true` in `Info.plist` to force-enable on-device (useful if backend not running).

---

## Production Notes

- Ensure the iOS app bundle ID and CloudKit container are correctly configured in Apple Developer.
- Use `CLOUDKIT_ENV=production` and a production Web Services key in production.
- Store secrets in your deployment platform’s secret manager; never commit them.
- The backend gracefully handles CloudKit outages by continuing local operations and logging cloud errors.

---

## Troubleshooting

- Cloud shows enabled but not available:
  - Verify `CLOUDKIT_CONTAINER_ID`, `CLOUDKIT_KEY_ID`, and `CLOUDKIT_PRIVATE_KEY` are set and valid.
  - Check `CLOUDKIT_ENV` matches your target environment.
- iOS doesn’t sync:
  - Confirm `GET /api/cloud/status` returns `enabled: true` and `available: true`.
  - Check device logs for CloudKit permission prompts and errors.
- Local dev without paid account:
  - Leave `CLOUDKIT_ENABLED=false`. Everything works locally; CloudKit code paths are skipped or simulated.

---

## Where Things Live

- Backend service: `roomies-backend/src/services/CloudKitService.ts`
- Health and cloud endpoints: `roomies-backend/src/server.ts` (`/health`, `/api/cloud/status`)
- iOS runtime toggles: `roomies-ios/HouseholdApp/Services/CloudRuntime.swift`
- iOS CloudKit client: `roomies-ios/HouseholdApp/Services/CloudSyncManager.swift`
- iOS entitlements: `roomies-ios/HouseholdApp/HouseholdApp.entitlements`
