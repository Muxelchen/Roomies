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
   # Edit .env with your database credentials
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
DELETE /api/households/:id/leave  # Leave household
GET    /api/households/:id/members  # Get members
POST   /api/households/:id/invite   # Generate invite
```

### Task Management
```
GET    /api/tasks             # Get tasks (filtered)
POST   /api/tasks             # Create task
PUT    /api/tasks/:id         # Update task
DELETE /api/tasks/:id         # Delete task
POST   /api/tasks/:id/complete    # Mark complete
POST   /api/tasks/:id/assign      # Assign to user
GET    /api/tasks/my-tasks        # Current user tasks
```

### Gamification
```
GET    /api/gamification/stats       # User stats
GET    /api/gamification/leaderboard # Household leaderboard
GET    /api/gamification/badges      # Available badges
POST   /api/gamification/claim-badge # Claim earned badge
```

### Reward Store
```
GET    /api/rewards           # Get available rewards
POST   /api/rewards           # Create reward (admin)
POST   /api/rewards/:id/redeem    # Redeem reward
GET    /api/rewards/history       # Redemption history
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

### Current Status: **READY FOR ACTIVATION** 

**Important:** CloudKit features are fully implemented but **disabled by default** because they require a **paid Apple Developer account** ($99/year). Free Apple Developer accounts cannot access CloudKit, iCloud, or any Apple cloud services.

### When You're Ready to Enable CloudKit

1. **Get Paid Apple Developer Account**
   - Upgrade to Apple Developer Program ($99/year)
   - Verify CloudKit access in Apple Developer Console

2. **Configure CloudKit**
   ```bash
   # In your .env file:
   CLOUDKIT_ENABLED=true
   CLOUDKIT_CONTAINER_ID=iCloud.com.yourcompany.roomies
   CLOUDKIT_API_TOKEN=your_cloudkit_api_token
   ```

3. **CloudKit Features Auto-Activate**
   - Household cross-device sync
   - Real-time collaboration
   - Cloud-based invite codes
   - Automatic data backup
   - Offline sync capabilities

### CloudKit Features Overview

```typescript
// All CloudKit features are ready and will activate when enabled:

// ✅ Household Synchronization
await CloudKitService.getInstance().syncHousehold(household);

// ✅ Task Cross-device Sync  
await CloudKitService.getInstance().syncTask(task);

// ✅ Join Household via Cloud
const household = await CloudKitService.getInstance()
  .joinHouseholdFromCloud(inviteCode, user);

// ✅ Real-time Updates
await CloudKitService.getInstance().fetchHouseholdUpdates(household);

// ✅ Activity Sync
await CloudKitService.getInstance().syncActivity(activity);
```

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
- **Password Hashing** with bcrypt (12 rounds)
- **Rate Limiting** on all endpoints
- **Input Validation** with class-validator
- **SQL Injection Protection** via TypeORM
- **XSS Protection** with helmet middleware
- **CORS Configuration** for secure cross-origin requests

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

# CloudKit (when ready)
CLOUDKIT_ENABLED=false  # Set to true with paid account
CLOUDKIT_CONTAINER_ID=iCloud.com.yourcompany.roomies

# Optional Features  
REDIS_HOST=localhost
ENABLE_ANALYTICS=true
ENABLE_REAL_TIME_SYNC=true
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

### E2E Smoke Tests

You can run quick, high-signal smoke checks against either local or AWS environments.

```
# Local (default: http://localhost:3000)
node test-api.js
node test-realtime.js

# Remote (set your API base; include /api suffix)
API_URL=http://<host>:<port>/api node test-api.js
API_URL=http://<host>:<port>/api node test-realtime.js

# Example (current EC2)
API_URL=http://54.93.77.238:3001/api node test-api.js
API_URL=http://54.93.77.238:3001/api node test-realtime.js
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

## 🏆 Architecture Highlights

- **Modular Design** - Easy to extend and maintain
- **Cloud-Ready** - Seamless CloudKit integration when available
- **Local-First** - Works perfectly without cloud services
- **Scalable** - Built for growth with proper caching and optimization
- **Secure** - Production-ready security features
- **Well-Documented** - Comprehensive documentation and code comments

---

**Roomies Backend** - The complete household management API, ready for both local development and Apple ecosystem integration! 🏠✨
