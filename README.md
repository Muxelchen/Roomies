# Roomies - iOS Household Management App

A gamified iOS app for household organization that makes managing tasks fun and engaging.

## 🏠 About the App

Roomies transforms household management into an engaging experience with gamification elements, task management, and reward systems to motivate household members.

## 🏗️ Architecture Overview

The app follows a clean architecture pattern with clear separation of concerns:

```
HouseholdApp/
├── 📱 Views/                     # SwiftUI Views & UI Components
│   ├── Authentication/          # Login/Register Views
│   ├── Dashboard/              # Main Dashboard
│   ├── Tasks/                  # Task Management
│   ├── Store/                  # Reward Store
│   ├── Challenges/             # Challenge System
│   ├── Leaderboard/            # User Rankings
│   ├── Profile/                # User Settings
│   ├── Analytics/              # Analytics Dashboard
│   └── Shared/                 # Reusable Components
├── 🔧 Services/                 # Business Logic & Managers
│   ├── AuthenticationManager.swift
│   ├── AnalyticsManager.swift
│   ├── CalendarManager.swift
│   ├── GameificationManager.swift
│   ├── NotificationManager.swift
│   ├── PerformanceManager.swift
│   └── UserDefaultsManager.swift
├── 🗄️ Models/                   # Data Layer
│   └── PersistenceController.swift
├── 📱 Widgets/                  # iOS Widgets
│   └── RoomiesWidget.swift
└── ⚙️ Configuration/
    ├── RoomiesApp.swift         # App Entry Point
    ├── Info.plist              # App Configuration
    └── HouseholdApp.entitlements # App Permissions
```

## ✨ Core Features

### 👥 Multi-User Households
- Create and manage multiple households
- User profiles with performance tracking
- Multiple household support
- Role-based permissions

### 📋 Task Management
- Create, edit, schedule, and assign tasks
- Task priorities and point values
- Recurring tasks (daily, weekly, monthly)
- **iOS Calendar Integration**: Tasks sync with Calendar app

### 🎮 Gamification System
- Point system for completed tasks
- Reward store to spend earned points
- Achievement system and badges
- Leaderboards and competitive rankings
- Time-limited challenges
- Streak tracking and celebrations

### 🔐 Authentication & Security
- Email/password authentication
- Secure credential storage with Keychain
- Privacy-focused data handling

### 📱 Native iOS Integration
- **iOS Widgets**: Home screen widgets with live task data
- **Calendar Sync**: Automatic task scheduling
- **Smart Notifications**: Task reminders and achievements
- **Background Processing**: Optimized performance

### 📊 Analytics Dashboard
- Productivity trends and completion rates
- User performance metrics
- Task distribution visualization
- Time analysis and insights

## 🚀 Getting Started

### Prerequisites
- **Xcode 14.0+** with iOS 16.0+ SDK
- **Swift 5.7+**
- **iOS 15.0+** device or simulator
- **Apple Developer Account** (for device testing)

### Installation
1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/Roomies.git
   cd Roomies
   ```

2. **Open in Xcode**
   ```bash
   open HouseholdApp.xcodeproj
   ```

3. **Configure signing**
   - Select your development team in project settings
   - Update bundle identifier if needed

4. **Build and run**
   - Select target device/simulator
   - Press ⌘+R to build and run

## 🛠️ Current Status

### ✅ Completed Features
- Multi-household support with proper assignment
- Task management system
- Reward store with point deduction
- Gamification elements
- iOS widgets and calendar integration
- Performance optimizations
- Core Data persistence

### 🔧 In Progress (See TODO.md)
- Task synchronization improvements
- Settings stability fixes
- Filter functionality
- Task completion checkbox
- Point awarding system

## 📚 Documentation

Available documentation:

- **[UI/UX Guidelines](docs/UI_UX_GUIDELINES.md)** - Complete design system and guidelines
- **[Changelog](docs/CHANGELOG.md)** - Version history and updates
- **[Security](docs/SECURITY.md)** - Security guidelines and practices
- **[TODO.md](TODO.md)** - Current bugs, features, and development roadmap

## 🐛 Bug Reports & Issues

Current known issues are tracked in [TODO.md](TODO.md). For new bugs or feature requests, please create an issue.

## 📱 Technology Stack

- **SwiftUI** - Modern declarative UI framework
- **Core Data** - Local data persistence
- **Combine** - Reactive programming
- **WidgetKit** - iOS home screen widgets
- **EventKit** - Calendar integration
- **LocalAuthentication** - Secure authentication
- **UserNotifications** - Push notifications

---

**Roomies** - Making household management organized and fun! 🏠✨

*Last updated: August 5, 2025*
