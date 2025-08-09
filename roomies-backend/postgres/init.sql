-- Optional initial SQL for production Postgres container
-- Adds performance indexes and sets sensible defaults

-- Example indexes (ensure names match your actual schema)
-- CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);
-- CREATE INDEX IF NOT EXISTS idx_households_invite_code ON households (invite_code);
-- CREATE INDEX IF NOT EXISTS idx_tasks_household_created ON household_tasks (household_id, created_at DESC);

-- You can also copy additional SQL from src/database/optimizations/add-performance-indexes.sql at deploy time.


