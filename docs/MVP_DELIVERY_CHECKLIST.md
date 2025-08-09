# MVP Delivery Plan and Checklist

## Definitions
- **Demoable MVP**: End-to-end flows run reliably against a live backend in a development/staging environment, with real-time updates, no major crashes, and basic smoke/E2E checks.
- **Ship-ready MVP**: Demoable features plus hardened deploy (HTTPS), error monitoring, basic automated tests, backups, and minimal ops runbooks.

## Success Criteria (Both)
- **Auth**: register, login, logout, JWT refresh
- **Households**: create, join, list members
- **Tasks**: CRUD, assign, complete, my tasks
- **Gamification**: points visible, leaderboard reads, achievements reads
- **Rewards**: CRUD, redeem, redemption history
- **Real-time**: task.created, task.completed, task.assigned, member.joined, points.updated
- **Stability**: no major crashes; graceful error responses
- Demoable: push notifications optional
- Ship-ready: HTTPS, monitoring, basic alerting, backups

---

## 1) Backend

### Current Integration Verification (Local Dev)

- Backend via Docker Compose at `http://127.0.0.1:3001` (maps container port 3000).
- Health: `GET /api/health` returns 200; dev container may report high memory usage (informational).
- Auth, Households, Tasks, Rewards: verified with provided CLI scripts.
- Real-time: SSE and Socket.IO verified end-to-end; iOS listens on `/api/events/household/:householdId`.
- iOS build: `HouseholdApp` Debug builds for iPhone 16 Simulator; scheme env sets `API_BASE_URL` and `SOCKET_URL` to `127.0.0.1`.
Quick verification commands:

```bash
cd roomies-backend
docker compose -f docker-compose.dev.yml up -d

curl -s http://127.0.0.1:3001/api/health | jq .

API_URL=http://127.0.0.1:3001/api node test-api.js
API_URL=http://127.0.0.1:3001/api node test-realtime.js
API_URL=http://127.0.0.1:3001/api node --experimental-fetch scripts/e2e-mvp.js

npm test

xcodebuild -scheme HouseholdApp \
  -project roomies-ios/HouseholdApp.xcodeproj \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Ship-ready follow-ups:

- Enable HTTPS and lock down CORS.
- Add monitoring/error tracking.
- Wire APNs (backend endpoint `POST /api/notifications/register-device` scaffolded; iOS toggle in `NotificationManager`).

### 1.1 Local Development (Demoable)
Prereqs: Node 18+, Docker, Docker Compose

Create `roomies-backend/.env.secure` (used by dev compose):

```dotenv
# Secrets – do not commit
JWT_SECRET=dev-change-me
EMAIL_FROM=roomiesappteam@gmail.com
# Optional SMTP (for password reset emails)
# SMTP_SERVICE=gmail
# SMTP_USER=roomiesappteam@gmail.com
# SMTP_PASS=your_app_password
# Optional CloudKit flags (kept false for demo)
CLOUDKIT_ENABLED=false
CLOUDKIT_USE_WEB_SERVICES=false
LOG_LEVEL=debug
```

Start the dev stack:

```bash
cd roomies-backend
docker compose -f docker-compose.dev.yml up -d
docker compose -f docker-compose.dev.yml logs -f backend
```

Notes:
- API base for iOS Simulator: `http://127.0.0.1:3001/api` (compose maps 3001→3000)
- Socket base for iOS Simulator: `http://127.0.0.1:3001`
- Health must return 200:

```bash
curl -i http://127.0.0.1:3001/health
```

Run migrations (if not auto-synced):

```bash
docker compose -f docker-compose.dev.yml exec backend npm run migrate
```

Smoke tests:

```bash
node roomies-backend/test-api.js
node roomies-backend/test-realtime.js
# Optional comprehensive script if present
node roomies-backend/scripts/e2e-mvp.js
```

Minimal curl checks:

```bash
# Register
curl -sS -X POST http://127.0.0.1:3001/api/auth/register \
 -H "Content-Type: application/json" \
 -d '{"email":"demo@roomies.app","password":"Password123!","name":"Demo User"}' | jq

# Login
curl -sS -X POST http://127.0.0.1:3001/api/auth/login \
 -H "Content-Type: application/json" \
 -d '{"email":"demo@roomies.app","password":"Password123!"}' | jq
# Copy accessToken from response to $TOKEN

# Create household
curl -sS -X POST http://127.0.0.1:3001/api/households \
 -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
 -d '{"name":"Demo Household"}' | jq

# Create task
curl -sS -X POST http://127.0.0.1:3001/api/tasks \
 -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
 -d '{"title":"Take out trash","priority":"medium"}' | jq
```

TypeScript/TypeORM gotchas to resolve if they surface:
- Request typing: ensure `src/types/express.d.ts` augments `Request.userId`
- Relations: use `where: { user: { id: req.userId } }` in TypeORM queries
- Remove non-existent fields (e.g., `Household.description`)
- Task entity: `task.assignedTo = userEntity`; `createdBy` is a string id

API references: see `roomies-backend/README.md` for complete endpoint lists.

Real-time events (Socket.IO): `task.created`, `task.completed`, `task.assigned`, `member.joined`, `reward.redeemed`, `points.updated`.

### 1.2 Staging/Production (Ship-ready)
Create `roomies-backend/.env.prod` (not committed):

```dotenv
DB_PASSWORD=replace_me_secure
REDIS_PASSWORD=replace_me_secure
JWT_SECRET=replace_me_with_256bit
EMAIL_FROM=roomiesappteam@gmail.com
# Optional SMTP_* variables if using email flows
```

TLS certs:
- Place `fullchain.pem` and `privkey.pem` into `roomies-backend/nginx/ssl/`
- Provide a valid `roomies-backend/nginx/nginx.conf` with 443→app proxy and `/health` passthrough

Build and run:

```bash
cd roomies-backend
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
```

Post-boot checks:
- `curl -ik https://your.domain/health` returns 200
- App logs show no unhandled exceptions:

```bash
docker compose -f docker-compose.prod.yml logs app | tail -n +1 | cat
```

Backups:
- Verify `backups/` is mounted and the `backup` service cron runs daily
- Manual test: exec into `backup` and run a `pg_dump` to `/backups/test.sql`

Monitoring:
- Node exporter exposed at `:9100` (secure behind firewall or reverse proxy)

Security must-haves:
- CORS allow-list restricted to trusted origins
- Rate limiting enabled on auth endpoints
- Error stack traces hidden in production
- HTTPS enforced at the edge (HSTS)

---

## 2) iOS App

### 2.1 Demoable Wiring
Set base URLs for Simulator:
- REST API: `http://127.0.0.1:3001/api`
- Socket.IO: `http://127.0.0.1:3001` (the client library selects ws)
- On a physical device: use your Mac’s LAN IP instead of 127.0.0.1

Ensure usage of integrated managers:
- `IntegratedAuthenticationManager` for auth + offline fallback
- `IntegratedTaskManager` for task CRUD + sync
- `SocketManager` for real-time events
- `NetworkManager` holds base URL and auth headers

Acceptance checklist:
- Launch app, register/login
- Create/join household
- Create/assign/complete a task
- See points update locally
- Observe real-time event when creating a task from another client/script

Local notifications (optional for demo):
- Use in-app/local notifications to show task completion feedback

### 2.2 Ship-ready Additions (APNs)
Push notifications (APNs):
- Store APNs AuthKey `.p8` securely (not in repo)
- Mount into backend via `roomies-backend/certs/AuthKey_<KEYID>.p8` and set:

```dotenv
APNS_KEY_PATH=/app/certs/AuthKey_<KEYID>.p8
APNS_KEY_ID=<KEYID>
APNS_TEAM_ID=<YOUR_TEAM_ID>
APNS_BUNDLE_ID=<your.bundle.id>
APNS_ENV=production   # or development
```

- Implement device token registration on backend:
  - `POST /api/notifications/register-device` with `{ token, platform: "ios" }`
- Send push on events (e.g., `task.completed`)
- Acceptance: device receives a push within < 5s of event

Crash/error monitoring:
- Enable Sentry/Crashlytics in app
- Backend returns normalized error payloads; log correlation IDs

Performance polish:
- Ensure main thread responsiveness; lazy lists; smooth 60fps animations

---

## 3) End-to-end Real-time Validation

Procedure:
1. Start two clients (iOS simulator + curl, or two simulators/devices)
2. Both logged into the same household
3. From client B, create a task via API
4. Client A receives `task.created` in under 1s and UI updates automatically

---

## 4) Test Plan

### 4.1 Backend Smoke/E2E (Both)
```bash
node roomies-backend/test-api.js
node roomies-backend/test-realtime.js
# Or, if present:
node roomies-backend/scripts/e2e-mvp.js
```

### 4.2 Functional Acceptance (Both)
- Auth: register, login, refresh, logout
- Household: create, join via invite code, list members
- Tasks: create, update, complete, assign, list per household and my tasks
- Gamification: leaderboard reads, achievement reads
- Rewards: create, redeem, history
- Real-time: verify live events on create/complete/assign

### 4.3 Ship-only Checks
- HTTPS enforced; HSTS configured
- Rate limits active (429 on abuse)
- Error redaction in prod
- Backup file produced and restorable
- Monitoring up (node exporter or equivalent)
- Push notification receipt on a physical device

---

## 5) Deployment Options

- Single VM with `docker-compose.prod.yml` (fastest path)
  - DNS → Nginx → App → Postgres/Redis
- PaaS (Render/Fly/Heroku) with managed Postgres/Redis
  - Map environment variables accordingly
- CI/CD (optional for ship)
  - Build on push to `main`
  - Run `npm run build` and smoke tests
  - Deploy with `docker compose` or platform CLI

---

## 6) Definition of Done

### Demoable MVP DoD
- Backend runs via `docker-compose.dev.yml` with healthy services
- iOS app points at `http://127.0.0.1:3001/api`
- All core flows pass and emit real-time events
- Smoke/E2E scripts green
- No crashes; user-friendly error messages

### Ship-ready MVP DoD
- Deployed behind HTTPS with working domain
- Secure secrets; 256-bit JWT secret; rate limiting; CORS lock-down
- Backups scheduled and tested
- Monitoring reachable to ops; error tracking active
- Basic test coverage for auth/tasks/households + E2E
- Push notifications working on a physical device
- Runbook for restart/backup/restore documented

---

## 7) Immediate Next Actions

Backend:
- Create `.env.secure`, run dev compose, run migrations
- Fix any TS/TypeORM mismatches that surface; re-run smoke tests

iOS:
- Point base URL to `http://127.0.0.1:3001/api`
- Ensure `SocketManager` connects to `ws://127.0.0.1:3001` and receives events

Ship (optional):
- Prepare `.env.prod`, TLS certs, DNS, run prod compose
- Add APNs with your `.p8` key and team/bundle IDs

E2E:
- Run `test-api.js` and `test-realtime.js`; resolve any failures immediately

---

## 8) Reference Files
- `roomies-backend/docker-compose.dev.yml`
- `roomies-backend/docker-compose.prod.yml`
- `roomies-backend/README.md` (API endpoints, setup)
