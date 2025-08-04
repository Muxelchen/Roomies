# Roomies - "Not Boring" iOS Household Management App

A vibrant, gamified iOS app for household organization that makes chores feel like a game, featuring stunning 3D animations, spring-based interactions, and a playful "Not Boring Apps" design philosophy.

## 🏠 About the App

Roomies transforms household management into an exciting, living experience. With its "Not Boring Apps" approach featuring 3D effects, fluid animations, and delightful micro-interactions, it's the most engaging way to organize your home.

## 🏗️ Architecture Overview

Roomies follows a **clean architecture pattern** with clear separation of concerns:

```
Roomies/
├── 📱 Frontend Layer (3D UI & Animations)
│   ├── Views/                    # SwiftUI Views with 3D Effects
│   ├── Widgets/                  # Animated iOS Widgets
│   ├── Assets.xcassets/         # Visual Resources
│   └── ContentView.swift        # Main Content View
├── 🔧 Backend Layer (Business Logic & Data)
│   ├── Services/                # Business Logic Managers
│   ├── Models/                  # Data Layer & Core Data
│   └── HouseholdModel.xcdatamodeld/ # Core Data Schema
└── ⚙️ Configuration Layer (App Setup)
    ├── RoomiesApp.swift         # App Entry Point
    ├── Info.plist              # App Configuration
    └── HouseholdApp.entitlements # App Permissions
```

### **Architecture Benefits:**
- ✅ **Clear Separation**: UI logic separated from business logic
- ✅ **Maintainable**: Changes in one layer don't affect others
- ✅ **Testable**: Isolated testing for each layer
- ✅ **Scalable**: Easy to add new features and services
- ✅ **Performant**: Optimized for 60 FPS animations

## ✨ Core Features

### 👥 Multi-User Households
- Create and manage multiple households with animated onboarding
- Invite members via invitation code or animated QR-Code
- User profiles with colorful avatars and performance tracking
- **Multiple household support**: Users can join and manage several households
- Role-based permissions with smooth transitions

### 📋 Simplified Task Management
- Create, edit, schedule, and assign tasks with gamified point values
- **No Photo Verification**: Simplified completion system focused on trust
- Recurring tasks (daily, weekly, monthly, custom) with visual indicators
- Task priorities with animated priority colors
- **iOS Calendar Integration**: Tasks sync automatically with Calendar app
- Spring-based animations for task completion celebrations

### 🔐 Simple & Secure
- **No Biometric Complexity**: Clean email/password authentication
- Secure credential storage with Keychain integration
- **Streamlined Security**: Focus on usability over complexity
- GDPR-compliant data handling and privacy controls

### 📱 Native iOS Integration
- **Animated iOS Widgets**: Small, Medium, and Large home screen widgets with live data
- **Calendar Sync**: Automatic task scheduling in iOS Calendar
- **Smart Notifications**: Engaging alerts for tasks and achievements
- **Background Processing**: Optimized performance for smooth animations
- **Deep Linking**: Seamless app-to-app navigation

### 📊 Beautiful Analytics Dashboard
- **Visual Productivity Trends**: 30-day completion rate with animated charts
- **User Performance Metrics**: Individual member analytics with celebrations
- **Task Distribution Visualization**: Animated category breakdowns
- **Time Analysis**: Peak productivity insights with smooth transitions
- **Gamified Insights**: Fun recommendations and progress tracking
- **Performance Monitoring**: Real-time app optimization

### 🎮 "Not Boring" Gamification
- **3D Point System**: Floating numbers and particle effects for completed tasks
- **Animated Reward Store**: Spend points on rewards with satisfying interactions
- **3D Achievement System**: Spinning medallions and badge ceremonies
- **Dynamic Leaderboards**: Competitive rankings with live animations
- **Epic Challenges**: Time-limited competitions with countdown timers
- **Streak Celebrations**: Confetti explosions and success animations

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
   - Update bundle identifier to `com.roomies.app`

4. **Build and run**
   - Select target device/simulator
   - Press ⌘+R to build and run

### Project Structure
```
HouseholdApp/
├── 📱 Frontend/
│   ├── Views/                    # SwiftUI Views with 3D Effects
│   │   ├── Authentication/       # Animated Login/Register
│   │   ├── Dashboard/           # 3D Dashboard
│   │   ├── Tasks/              # Interactive Task Management
│   │   ├── Store/              # Animated Reward Store
│   │   ├── Challenges/         # Gamified Challenges
│   │   ├── Leaderboard/        # Dynamic Rankings
│   │   ├── Profile/            # Settings & Profile
│   │   └── Shared/             # Reusable 3D Components
│   ├── Widgets/                # Animated iOS Widgets
│   ├── Assets.xcassets/        # Visual Resources
│   └── ContentView.swift       # Main content view
├── 🔧 Backend/
│   ├── Services/               # Business Logic
│   │   ├── AuthenticationManager.swift
│   │   ├── NotificationManager.swift
│   │   ├── CalendarManager.swift
│   │   ├── AnalyticsManager.swift
│   │   ├── PerformanceManager.swift
│   │   ├── GameificationManager.swift
│   │   ├── SampleDataManager.swift
│   │   └── LoggingManager.swift
│   ├── Models/                 # Data Layer
│   │   ├── PersistenceController.swift
│   │   ├── AuthenticationManager.swift
│   │   └── LocalizationManager.swift
│   └── HouseholdModel.xcdatamodeld/ # Core Data
└── ⚙️ Configuration/
    ├── RoomiesApp.swift        # App entry point
    ├── Info.plist             # App configuration
    └── HouseholdApp.entitlements # Permissions
```

## 🎨 "Not Boring" Design Philosophy

Roomies follows the "Not Boring Apps" design philosophy:

- **3D-First Design**: Everything has depth, shadows, and physical presence
- **Fluid Animations**: Spring-based interactions that feel alive
- **Micro-Interactions**: Every tap, swipe, and gesture has delightful feedback
- **Vibrant Colors**: Energetic oranges, electric blues, and magic purples
- **Playful Typography**: Rounded fonts and animated text effects
- **Gamification**: Points, particles, and celebrations make everything fun

For complete design guidelines, see our [UI/UX Guidelines](docs/UI_UX_GUIDELINES.md).

## 📚 Documentation

Complete project documentation is available in the `docs/` directory:

- **[UI/UX Guidelines](docs/UI_UX_GUIDELINES.md)** - Complete "Not Boring" design system
- **[Architecture Strategy](docs/ARCHITECTURE_STRATEGY.md)** - Technical architecture decisions
- **[API Documentation](docs/API_DOCUMENTATION.md)** - Complete API reference
- **[Build Guide](docs/BUILD_READY_CHECKLIST.md)** - Build and deployment instructions
- **[Changelog](docs/CHANGELOG.md)** - Version history and updates
- **[Project Summary](docs/PROJECT_SUMMARY.md)** - Comprehensive overview
- **[Privacy Policy](docs/PRIVACY.md)** - Privacy policy and data handling
- **[Security](docs/SECURITY.md)** - Security guidelines and practices

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](docs/CONTRIBUTING.md) for details.

## 📞 Support

For support and feature requests, please open an issue on GitHub or contact us at support@roomies.app

---

**Roomies** - Making household management fun, animated, and delightfully "not boring"! 🏠✨🎮
