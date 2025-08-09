# 🏠 Roomies Backend API

A comprehensive backend API for the **Roomies** gamified household management platform, built with Node.js, TypeScript, TypeORM, and PostgreSQL. This backend supports both local-first development and CloudKit integration for seamless Apple ecosystem integration.

## 🌟 Key Features

### ✅ **Currently Available (No CloudKit Required)**
- **Complete Authentication System** - JWT-based auth with secure password hashing
- **Household Management** - Create/join households with invite codes  
- **Task Management** - Full CRUD with assignments, priorities, and recurring tasks
- **Gamification System** - Points, levels, badges, achievements, and leaderboards
- **Reward Store** - Point-based reward system with redemption tracking
- **Challenge System** - Timed challenges with participant tracking
- **Activity Logging** - Comprehensive activity feed and analytics
- **Real-time Updates** - WebSocket support for live household updates
- **Local Storage First** - Works perfectly without cloud services

### 🔄 **CloudKit Features (Ready for Activation)**
- **Cross-device Sync** - Automatic synchronization across Apple devices
- **Household Discovery** - Join households via CloudKit invite codes
- **Real-time Collaboration** - Live updates across all family members
- **Data Backup** - Automatic cloud backup of all household data
- **Offline-first Design** - Works offline, syncs when connected

## 🚀 Quick Start

### Prerequisites
- **Node.js 18+** and **npm 9+**
- **PostgreSQL 14+** (or Docker)
- **Redis 6+** (optional, for caching)
- **Apple Developer Account** (for CloudKit features)

### Environment

Create a `.env` at project root with at least:

```
CLOUDKIT_ENABLED=false
CLOUDKIT_USE_WEB_SERVICES=false
DATABASE_URL=postgresql://localhost:5432/roomies_dev
PORT=3000
```

To enable CloudKit later, add:

```
CLOUDKIT_ENABLED=true
CLOUDKIT_CONTAINER_ID=iCloud.com.yourcompany.roomies
# For Web Services server-to-server signing:
CLOUDKIT_USE_WEB_SERVICES=true
CLOUDKIT_ENV=development            # or production
CLOUDKIT_KEY_ID=XXXXXXXXXX          # Key ID from Apple Developer
CLOUDKIT_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIIEv...\n-----END PRIVATE KEY-----\n"
# Optional token for other auth scenarios
CLOUDKIT_API_TOKEN=your_token
```

### Installation

1. **Clone and Install**
   ```bash
   git clone <repository-url>
   cd roomies-backend
   npm install
   ```

2. **Environment Setup**
   ```bash
   cp .env.example .env
   # Optional environment templates for staging/production are available:
   # .env.staging.example and .env.production.example
   # Copy and fill them to `.env` for your target environment
   ```

3. **Database Setup**
   ```bash
   # Create PostgreSQL database
   createdb roomies_dev
   
   # Run migrations (auto-created by TypeORM)
   npm run dev  # Will auto-sync database schema
   ```

4. **Start Development Server**
   ```bash
   npm run dev
   ```

The API will be available at `http://localhost:3000`

## 📊 API Documentation

### Authentication Endpoints
```
POST   /api/auth/register     # Register new user
POST   /api/auth/login        # User login
POST   /api/auth/refresh      # Refresh JWT token
POST   /api/auth/logout       # User logout
GET    /api/auth/me           # Get current user
POST   /api/auth/change-password  # Change password
```

### Household Management
```
POST   /api/households        # Create household
GET    /api/households/:id    # Get household details
PUT    /api/households/:id    # Update household
POST   /api/households/join   # Join via invite code
POST   /api/households/leave  # Leave household
GET    /api/households/:id/members  # Get members
POST   /api/households/:id/invite   # Get/regenerate invite
DELETE /api/households/:id/members/:userId # Remove member (admin)
```

### Task Management
```
GET    /api/tasks/household/:householdId  # Get tasks for household
POST   /api/tasks             # Create task
PUT    /api/tasks/:id         # Update task
DELETE /api/tasks/:id         # Delete task
POST   /api/tasks/:id/complete    # Mark complete
POST   /api/tasks/:id/assign      # Assign to user
GET    /api/tasks/my-tasks        # Current user tasks
```

### Gamification
```
GET    /api/gamification/stats                 # Global activity stats
GET    /api/gamification/leaderboard/:householdId  # Household leaderboard
GET    /api/gamification/achievements          # Current user's achievements
POST   /api/gamification/claim-achievement     # Claim earned achievement (TBD)
```

### Reward Store
```
GET    /api/rewards/household/:householdId # Get available rewards for a household
POST   /api/rewards                      # Create reward (admin)
PUT    /api/rewards/:id                  # Update reward (admin)
DELETE /api/rewards/:id                  # Delete reward (admin)
POST   /api/rewards/:id/redeem           # Redeem reward
GET    /api/rewards/history/my           # Current user's redemption history
```

### Real-time WebSocket Events
```
task.completed             # Task was completed
task.created               # New task created
task.assigned              # Task assigned to user
member.joined              # New member joined
reward.redeemed            # Reward was redeemed
points.updated             # User points changed
challenge.completed        # Challenge completed
```

## ☁️ CloudKit Integration

### Current Status: **CloudKit Ready (AWS removed)** 

This backend has removed all AWS dependencies and is now CloudKit-first. CloudKit features are scaffolded and disabled by default via `CLOUDKIT_ENABLED=false`. When enabled and credentials provided, CloudKit paths activate system-wide.

### When You're Ready to Enable CloudKit

1. **Get Paid Apple Developer Account**
   - Upgrade to Apple Developer Program ($99/year)
   - Verify CloudKit access in Apple Developer Console

2. **Configure CloudKit**
```bash
# In your .env file:
CLOUDKIT_ENABLED=true
CLOUDKIT_CONTAINER_ID=iCloud.com.yourcompany.roomies
# Optional if using CloudKit Web Services auth flow
CLOUDKIT_API_TOKEN=your_cloudkit_api_token
```

3. **CloudKit Features Auto-Activate**
   - Household cross-device sync
   - Real-time collaboration
   - Cloud-based invite codes
   - Automatic data backup
   - Offline sync capabilities

### CloudKit Features Overview

All CloudKit features are scaffolded and will activate when enabled:

- Household sync: `CloudKitService.getInstance().syncHousehold(household)`
- Task sync: `CloudKitService.getInstance().syncTask(task)`
- Join via invite code: `CloudKitService.getInstance().joinHouseholdFromCloud(code, user)`
- Fetch updates: `CloudKitService.getInstance().fetchHouseholdUpdates(household)`
- Activity sync: `CloudKitService.getInstance().syncActivity(activity)`

### Local-First Design Philosophy

This backend is designed with a **local-first** approach:

- **Works perfectly without CloudKit** - All features function locally
- **Graceful cloud integration** - CloudKit enhances but doesn't break functionality  
- **No cloud lock-in** - Your data remains accessible locally
- **Seamless transition** - Enable CloudKit anytime without migration

## 🛠️ Development

### Project Structure
```
src/
├── config/              # Database and app configuration
├── controllers/         # Request handlers
├── middleware/          # Auth, error handling, rate limiting
├── models/             # TypeORM entities
├── routes/             # API route definitions
├── services/           # Business logic (CloudKit, Gamification)
├── utils/              # Utilities (JWT, logging)
└── server.ts           # Application entry point
```

### Database Schema

The backend includes comprehensive data models:

- **Users** - Authentication, points, streaks, badges
- **Households** - Shared living spaces with invite codes
- **Tasks** - Assignments, priorities, recurring tasks, completion tracking
- **Rewards** - Point-based store with redemption tracking
- **Challenges** - Timed household challenges
- **Activities** - Comprehensive activity logging
- **Badges** - Achievement system with progress tracking

### Available Scripts

```bash
npm run dev          # Development server with hot reload
npm run build        # Build production version
npm start            # Start production server
npm run test         # Run test suite
npm run lint         # ESLint code checking
npm run lint:fix     # Fix ESLint issues
npm run migrate      # Run database migrations
npm run seed         # Seed database with sample data
```

### Testing

```bash
# Run all tests
npm test

# Run specific test categories
npm run test:unit        # Unit tests
npm run test:integration # Integration tests
npm run test:e2e         # End-to-end tests

# Test with coverage
npm run test:coverage
```

## 🔒 Security Features

- **JWT Authentication** with secure token management
- **Email Verification** with tokenized links
- **Password Reset** via tokenized email links
- **Password Hashing** with bcrypt (12 rounds)
- **Rate Limiting** on all endpoints
- **Input Validation** with class-validator
- **SQL Injection Protection** via TypeORM
- **XSS Protection** with helmet middleware
- **CORS Configuration** for secure cross-origin requests
- In production, Apple Sign-In strictly enforces `APP_BUNDLE_ID` audience matching
- Optional DB-backed refresh tokens (`ENABLE_REFRESH_TOKENS=true`) with revoke on logout/account deletion

## 📈 Performance & Monitoring

- **Database Connection Pooling** for optimal performance
- **Redis Caching** for frequently accessed data
- **Query Optimization** with TypeORM query builder
- **Request Logging** with Winston
- **Performance Monitoring** with built-in metrics
- **Error Tracking** with comprehensive error handling

## 🌍 Environment Configuration

Key environment variables:

```bash
# Essential Settings
NODE_ENV=development
PORT=3000
DATABASE_URL=postgresql://localhost:5432/roomies_dev
JWT_SECRET=your-secret-key
JWT_EXPIRES_IN=7d

# Apple Sign-In (production requires APP_BUNDLE_ID)
APP_BUNDLE_ID=com.yourcompany.Roomies

# Refresh tokens (MVP off by default)
ENABLE_REFRESH_TOKENS=false

# CloudKit (when ready)
CLOUDKIT_ENABLED=false  # Set to true with paid account
CLOUDKIT_CONTAINER_ID=iCloud.com.yourcompany.roomies

# Optional Features  
REDIS_HOST=localhost
ENABLE_ANALYTICS=true
ENABLE_REAL_TIME_SYNC=true

# Email (for auth/reset emails)
EMAIL_FROM=roomiesappteam@gmail.com
# Use one of the following SMTP setups:
# 1) Well-known service (e.g., Gmail) with app password
# SMTP_SERVICE=gmail
# SMTP_USER=roomiesappteam@gmail.com
# SMTP_PASS=your_app_password
# 2) Explicit SMTP server
# SMTP_HOST=smtp.example.com
# SMTP_PORT=587
# SMTP_SECURE=false
```

## 🚀 Deployment

### Production Deployment

1. **Environment Setup**
   ```bash
   NODE_ENV=production
   DATABASE_URL=your_production_db_url
   JWT_SECRET=secure_production_secret
   ```

2. **Build and Deploy**
   ```bash
   npm run build
   npm start
   ```

3. **Database Migration**
   ```bash
   npm run migrate
   ```

### Docker Deployment

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build
EXPOSE 3000
CMD ["npm", "start"]
```

## 🧪 Development Workflow

### Local Development with CloudKit Testing

```bash
# 1. Start with CloudKit disabled (default)
CLOUDKIT_ENABLED=false npm run dev

# 2. Test all functionality locally
npm run test

# 3. When ready, simulate CloudKit enabling
CLOUDKIT_ENABLED=true npm run dev

### Email Verification & Reset

- POST `/api/auth/register` sends a verification email to the user.
- POST `/api/auth/verify-email` with `{ email, token }` marks the email as verified.
- POST `/api/auth/forgot-password` sends a password reset link.
- POST `/api/auth/reset-password` with `{ email, token, newPassword }` resets the password.

# 4. All CloudKit features activate with proper fallbacks
```

### Adding New Features

1. **Create Model** in `src/models/`
2. **Add Controller** in `src/controllers/`  
3. **Define Routes** in `src/routes/`
4. **Update CloudKit Service** if cloud sync needed
5. **Add Tests** for all functionality
6. **Update Documentation**

## 📞 Support & Contributing

### Common Issues

**Q: CloudKit features not working?**
A: Ensure you have a paid Apple Developer account and `CLOUDKIT_ENABLED=true`

**Q: Database connection errors?**  
A: Check PostgreSQL is running and credentials in `.env` are correct

**Q: JWT token errors?**
A: Verify `JWT_SECRET` is set in environment variables

### Development Guidelines

- Follow TypeScript strict mode
- Use TypeORM for all database operations
- Implement comprehensive error handling
- Add CloudKit sync for user-facing data changes
- Include proper logging and monitoring
- Write tests for all new functionality

### E2E Smoke Tests (Local / Remote)

You can run quick, high-signal smoke checks against local or your chosen hosting environment.

```
# Local (default: http://localhost:3000)
node test-api.js
node test-realtime.js

# Remote (set your API base; include /api suffix)
API_URL=http://<host>:<port>/api node test-api.js
API_URL=http://<host>:<port>/api node test-realtime.js
```

Notes:
- `test-api.js` checks health, auth basics, and protected routes.
- `test-realtime.js` verifies SSE and Socket.IO events by creating a household and a task.
- For HTTPS domains, use `https://.../api` and ensure CORS/socket settings allow your client origin.

### CloudKit Development Notes

All CloudKit integration is marked with clear TODOs:
```typescript
// TODO: When CloudKit is available, implement:
// 1. Actual CloudKit CKRecord operations
// 2. Conflict resolution
// 3. Real-time change notifications
```

This makes it easy to find and implement actual CloudKit code when your paid developer account is ready.

### CloudKit Setup Docs

See `documentation/CLOUDKIT_SETUP.md` for a complete guide on:

- Required keys and secrets
- .env variables to enable CloudKit
- Local verification steps and health endpoints
- iOS entitlements and runtime toggles

## 🏆 Architecture Highlights

- **Modular Design** - Easy to extend and maintain
- **Cloud-Ready** - Seamless CloudKit integration when available
- **Local-First** - Works perfectly without cloud services
- **Scalable** - Built for growth with proper caching and optimization
- **Secure** - Production-ready security features
- **Well-Documented** - Comprehensive documentation and code comments

---

**Roomies Backend** - The complete household management API, ready for both local development and Apple ecosystem integration! 🏠✨
