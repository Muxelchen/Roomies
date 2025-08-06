# 🏠 Roomies Backend MVP Plan

## Overview
Backend API for the Roomies household management app - a gamified platform for managing household tasks, rewards, and member coordination.

## 🎯 Core Features for MVP

### 1. Authentication & User Management
**Essential for household member management**
- User registration/login with JWT
- Household creation and joining
- User profiles with avatars
- Role management (admin/member)

**Endpoints:**
```
POST   /api/auth/register
POST   /api/auth/login
POST   /api/auth/refresh
POST   /api/auth/logout
GET    /api/users/profile
PUT    /api/users/profile
POST   /api/users/avatar
```

### 2. Household Management
**Core of the app - managing shared living spaces**
- Create/join households
- Invite members via code/link
- Household settings and preferences
- Member management

**Endpoints:**
```
POST   /api/households
GET    /api/households/:id
PUT    /api/households/:id
POST   /api/households/join
POST   /api/households/:id/invite
DELETE /api/households/:id/members/:userId
GET    /api/households/:id/members
```

### 3. Task Management
**Daily household task coordination**
- Create/edit/delete tasks
- Assign tasks to members
- Recurring tasks (daily/weekly/monthly)
- Task completion tracking
- Priority levels

**Endpoints:**
```
GET    /api/tasks
POST   /api/tasks
PUT    /api/tasks/:id
DELETE /api/tasks/:id
POST   /api/tasks/:id/complete
POST   /api/tasks/:id/assign
GET    /api/tasks/my-tasks
```

### 4. Gamification System
**Making chores fun and engaging**
- Points for completed tasks
- Levels and experience
- Streaks tracking
- Achievements/badges

**Endpoints:**
```
GET    /api/gamification/stats
GET    /api/gamification/leaderboard
GET    /api/gamification/achievements
POST   /api/gamification/claim-achievement
```

### 5. Reward Store
**Motivation through rewards**
- Create household rewards
- Spend points on rewards
- Reward redemption tracking

**Endpoints:**
```
GET    /api/rewards
POST   /api/rewards
PUT    /api/rewards/:id
DELETE /api/rewards/:id
POST   /api/rewards/:id/redeem
GET    /api/rewards/history
```

### 6. Real-time Updates
**Keep everyone in sync**
- WebSocket for live updates
- Task completion notifications
- New member notifications
- Points/reward updates

**WebSocket Events:**
```
task.created
task.completed
task.assigned
member.joined
reward.redeemed
points.updated
```

### 7. Push Notifications
**Reminders and updates**
- Task reminders
- Achievement notifications
- Household activity alerts

**Endpoints:**
```
POST   /api/notifications/register-device
PUT    /api/notifications/preferences
POST   /api/notifications/test
```

## 📊 Database Schema

### Core Tables
```sql
-- Users table
users (
  id, email, username, password_hash, 
  avatar_url, created_at, last_login
)

-- Households table
households (
  id, name, invite_code, created_by, 
  created_at, settings_json
)

-- Household members junction
household_members (
  household_id, user_id, role, 
  joined_at, points, level, streak_days
)

-- Tasks table
tasks (
  id, household_id, title, description,
  assigned_to, created_by, priority,
  points_value, due_date, recurrence_rule,
  completed_at, completed_by, status
)

-- Rewards table
rewards (
  id, household_id, title, description,
  points_cost, icon, created_by, 
  available_quantity, created_at
)

-- Reward redemptions
reward_redemptions (
  id, reward_id, user_id, redeemed_at,
  points_spent
)

-- Achievements table
achievements (
  id, name, description, icon, 
  points_value, criteria_json
)

-- User achievements junction
user_achievements (
  user_id, achievement_id, earned_at
)

-- Activity log
activity_log (
  id, household_id, user_id, action_type,
  entity_type, entity_id, metadata_json,
  created_at
)
```

## 🚀 Implementation Phases

### Phase 1: Foundation (Week 1)
- [x] Project setup and structure
- [ ] Database schema and migrations
- [ ] Authentication system
- [ ] Basic user management
- [ ] Household creation/joining

### Phase 2: Core Features (Week 2)
- [ ] Task CRUD operations
- [ ] Task assignment and completion
- [ ] Points system
- [ ] Basic gamification (points, levels)

### Phase 3: Rewards & Gamification (Week 3)
- [ ] Reward store implementation
- [ ] Achievement system
- [ ] Leaderboard
- [ ] Streak tracking

### Phase 4: Real-time & Polish (Week 4)
- [ ] WebSocket implementation
- [ ] Push notifications
- [ ] Activity feed
- [ ] Performance optimization
- [ ] Testing and bug fixes

## 🔧 Technical Stack

### Core Technologies
- **Node.js + TypeScript** - Runtime and language
- **Express.js** - Web framework
- **PostgreSQL** - Primary database
- **Redis** - Caching and sessions
- **Socket.io** - Real-time updates
- **JWT** - Authentication

### Additional Services
- **Expo Push Notifications** - Mobile notifications
- **Sharp** - Image processing for avatars
- **Node-cron** - Scheduled tasks (streaks, reminders)
- **Nodemailer** - Email notifications

## 📱 API Design Principles

### RESTful Standards
- Consistent naming conventions
- Proper HTTP status codes
- Pagination for list endpoints
- Filtering and sorting support

### Response Format
```json
{
  "success": true,
  "data": {},
  "message": "Operation successful",
  "timestamp": "2025-01-06T12:00:00Z"
}
```

### Error Format
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input",
    "details": []
  },
  "timestamp": "2025-01-06T12:00:00Z"
}
```

## 🔒 Security Considerations

### Must Have
- Password hashing (bcrypt)
- JWT with refresh tokens
- Input validation
- SQL injection prevention
- Rate limiting
- CORS configuration

### Nice to Have
- Two-factor authentication
- API key for external integrations
- Request signing

## 📈 Success Metrics

### Technical
- API response time < 200ms
- 99.9% uptime
- Support 1000+ concurrent users
- Real-time updates < 100ms latency

### Functional
- Complete task lifecycle working
- Points system calculating correctly
- Rewards can be created and redeemed
- Notifications delivered reliably
- Multi-household support working

## 🎯 MVP Deliverables

1. **Working API** with all core endpoints
2. **Database** with proper schema and indexes
3. **Real-time updates** via WebSocket
4. **Push notifications** for iOS
5. **Basic admin panel** for household management
6. **API documentation** (Swagger/OpenAPI)
7. **Deployment ready** with Docker

## 🚫 Not in MVP (Future Features)

- Shopping list management
- Expense splitting
- Calendar integration
- Advanced analytics
- Social features (comments, likes)
- Third-party integrations
- Advanced scheduling algorithms
- AI-powered task suggestions
- Voice commands
- Web application
