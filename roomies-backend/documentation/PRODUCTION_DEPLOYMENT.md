# Production Deployment Guide (Public Cloud)

This guide documents how to deploy the Roomies backend to a public cloud so other users can register and use the app without a local server.

---

## What you’ll need

- A domain (optional but recommended), e.g., api.yourdomain.com
- A cloud host (Render, Railway, Fly.io, or your own VM)
- PostgreSQL database URL
- Optional Redis (for caching; the app works without it)
- Apple Developer Program (for Sign in with Apple, CloudKit)

---

## Critical environment variables (production)

Set these on your hosting platform:

```
NODE_ENV=production
JWT_SECRET=<long_random_secret>
DATABASE_URL=postgresql://<user>:<pass>@<host>:5432/<db>

# CloudKit
CLOUDKIT_ENABLED=true
CLOUDKIT_CONTAINER_ID=iCloud.de.roomies.HouseholdApp
# Optional: Server-to-server Web Services (recommended for prod if used)
# CLOUDKIT_USE_WEB_SERVICES=true
# CLOUDKIT_ENV=production
# CLOUDKIT_KEY_ID=<apple_key_id>
# CLOUDKIT_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n
# Apple Sign-In
APP_BUNDLE_ID=de.roomies.HouseholdApp

# CORS (only needed if you use a web client)
# CLIENT_URL=https://your-web-origin
```

First deploy only (to auto-create tables): set `DB_SYNCHRONIZE=true`. After the first successful deploy and health check, remove it or set to `false` and redeploy.

Notes:
- Do not commit secrets. Use your platform’s secret manager.
- In production, Apple Sign-In requires `APP_BUNDLE_ID`.

---

## Option A: Render (fastest path)

1) Create a managed PostgreSQL instance on Render; copy the connection string into `DATABASE_URL`.
2) Create a new Web Service → Connect this GitHub repo
3) Configure runtime:
   - Environment: Node 18+
   - Build Command: `npm ci && npm run build`
   - Start Command: `npm start`
4) Add Environment Variables (above). Save & deploy.
5) Add a custom domain (optional) and enable HTTPS.
6) Health check: `GET https://<your-render-url>/health` should return 200.

---

## Option B: Docker Compose on your own VM

On an Ubuntu VM with Docker:

```
sudo apt-get update && sudo apt-get install -y docker.io docker-compose
cd /opt
sudo git clone <your-repo> roomies
cd roomies/roomies-backend

# Create environment file
cp .env.example .env.production
# Edit .env.production and set all required variables from the list above

# Start containers
sudo docker-compose -f docker-compose.prod.yml up -d --build
```

- Put Nginx in front for HTTPS. Use the provided `nginx/` config as a starting point.
- Health check: `GET http(s)://<your-host>/health`.

---

## Keeping it running

- If using Docker Compose: `docker ps`, `docker logs`, `docker-compose restart`.
- If using a plain VM (no Docker): use `pm2` with `ecosystem.config.js` in this repo:
  - `npm i -g pm2`
  - `pm2 start ecosystem.config.js`
  - `pm2 save && pm2 startup`

Set up uptime monitoring (e.g., UptimeRobot) on `https://your-api/health`.

---

## iOS app configuration for public API

- For device builds, set `API_BASE_URL` to your public API:
  - Xcode → Product → Scheme → Edit Scheme… → Run → Arguments → Environment
  - `API_BASE_URL=https://api.yourdomain.com/api`
- Release builds should use HTTPS (ATS-compliant). Avoid HTTP unless you add an ATS exception.
- Apple Sign-In will work if `APP_BUNDLE_ID` matches the app, and the device is signed into iCloud.

---

## Verifying after deploy

- Health: `curl -fsS https://api.yourdomain.com/health`
- Cloud: `curl -fsS https://api.yourdomain.com/api/cloud/status`
- Quick smoke tests from your laptop:
  - `API_URL=https://api.yourdomain.com/api node test-api.js`
  - `API_URL=https://api.yourdomain.com/api node test-realtime.js`

From the app:
- Launch on a device → Sign in with Apple → backend should log `POST /api/auth/apple` 200.

---

## Troubleshooting

- 400 on `/auth/apple` with empty name/email:
  - The client must not send empty strings. The app cleans these now.
- 401 on `/events/status`:
  - This endpoint is auth-protected; it’s fine to get 401 when unauthenticated. Use `/api/cloud/status` for cloud checks.
- Connection refused / timeouts from device:
  - Ensure API is public and HTTPS. Verify with Safari on the device.
  - Check firewall and security groups.
- CloudKit not “available” in status:
  - Set `CLOUDKIT_ENABLED=true` and `CLOUDKIT_CONTAINER_ID`. For Web Services, add key id/private key and `CLOUDKIT_USE_WEB_SERVICES=true`.

---

## Rollback plan

- Keep last known working image (Docker tag) or previous Render deploy.
- If a deploy fails, roll back to the prior version from your host’s history.
