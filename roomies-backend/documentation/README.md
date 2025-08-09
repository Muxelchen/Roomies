Backend auth/security notes

- APP_BUNDLE_ID: In production, Sign in with Apple requires APP_BUNDLE_ID to match the iOS app bundle id. Server rejects Apple tokens if unset.
- ENABLE_REFRESH_TOKENS: When 'true', the API issues DB-backed refresh tokens stored in `refresh_tokens` table and verifies on /auth/refresh. When 'false' (default), stateless refresh is used for MVP.

Environment variables

- APP_BUNDLE_ID
- ENABLE_REFRESH_TOKENS ("true" | "false")
- JWT_SECRET, JWT_EXPIRES_IN
- DATABASE_URL
- REDIS_HOST, REDIS_PORT, REDIS_PASSWORD (optional)
- CLIENT_URL
- SENTRY_DSN (optional)


