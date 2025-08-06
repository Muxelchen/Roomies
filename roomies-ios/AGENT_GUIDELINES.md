# AI Agent Guidelines for Roomies Project

## Overview
This document provides comprehensive guidelines for AI agents working with the Roomies codebase. Follow these guidelines to ensure consistent, efficient, and safe interactions with the project.

## Project Information
- **Project Name**: Roomies (iOS App + Backend)
- **Base Path**: `/Users/Max/Roomies`
- **Working Directory**: `/Users/Max/Roomies/roomies-ios`
- **Platform**: macOS
- **Shell**: zsh 5.9
- **Architecture**: iOS SwiftUI App + TypeScript/Node.js Backend
- **Primary Language**: Swift (iOS), TypeScript (Backend)
- **Target iOS Version**: iOS 17.0+
- **Xcode Version**: 14.0+

## Core Principles

### 1. Safety First
- Never execute commands that could harm the system or delete important data
- Always validate user intent before performing destructive operations
- Avoid exposing sensitive information or credentials
- Use environment variables for secrets, never hardcode them

### 2. Code Quality
- Maintain existing code style and conventions
- Write clean, readable, and well-documented code
- Follow the project's established patterns and idioms
- Test changes before considering them complete
- Update dependencies and related code when making changes

### 3. Communication
- Be clear and concise in explanations
- Ask for clarification when requirements are ambiguous
- Provide context for suggested changes
- Explain the reasoning behind technical decisions

## Project Structure

### iOS App Structure (HouseholdApp)
```
HouseholdApp/
├── Views/                  # SwiftUI Views organized by feature
├── Services/               # Singleton managers for business logic
├── Models/                 # Core Data entities and persistence
├── Extensions/             # Swift extensions and utilities
├── Widgets/                # iOS WidgetKit widgets
└── Assets.xcassets/        # Images and color assets
```

### Backend Structure
```
backend/
├── src/                    # TypeScript source code
├── scripts/                # Database migration and seeding
├── docker-compose.yml      # Docker configuration
└── package.json            # Node.js dependencies
```

## Working with the Codebase

### File Operations
- **Reading**: Use the `read_files` tool for examining code, not terminal commands
- **Editing**: Use the `edit_files` tool for code modifications
- **Creating**: Use the `create_file` tool for new files
- **Searching**: Use `search_codebase` for semantic searches, `grep` for exact matches

### Version Control
- Assume Git is the version control system unless specified otherwise
- Use `--no-pager` flag with git commands to avoid pagination issues
- Check git status before making changes
- Don't automatically commit or push changes without user confirmation

### Directory Navigation
- Use absolute paths when possible to avoid confusion
- Maintain awareness of the current working directory
- Avoid unnecessary `cd` commands; use absolute paths instead

## Best Practices

### Code Modifications
1. **Understand Before Editing**: Always read and understand existing code before modifying
2. **Preserve User Changes**: Never override user modifications marked with "This update includes user edits!"
3. **Incremental Changes**: Make small, focused changes rather than large rewrites
4. **Dependency Awareness**: Check for upstream and downstream dependencies
5. **Syntax Validation**: Ensure code remains syntactically correct after changes
6. **Swift-Specific**: Follow SwiftUI conventions, use @StateObject/@ObservedObject appropriately
7. **TypeScript-Specific**: Use proper typing, avoid `any` type unless necessary

### Testing and Validation
- Run relevant tests after making changes
- Verify compilation for compiled languages
- Check for linting errors
- Validate that changes meet the original requirements
- **iOS Testing**: Build in Xcode and test on simulator/device
- **Backend Testing**: Run `npm test` for unit tests
- **Integration Testing**: Verify API endpoints with proper authentication

### Performance Considerations
- Process large files in 5,000-line chunks when necessary
- Combine nearby line ranges into single requests when possible
- Use appropriate tools for the task (grep for exact matches, search_codebase for semantic queries)

## Tool Usage Guidelines

### search_codebase
- Use for semantic queries when file locations are unknown
- Avoid if relevant files are already identified
- Don't retry if a search fails

### grep
- Use for exact string or pattern matching
- Format queries as Extended Regular Expressions (ERE)
- Escape special characters: `(`, `)`, `[`, `]`, `.`, `*`, `?`, `+`, `|`, `^`, `$`

### read_files
- Prefer over terminal commands (`cat`, `head`, `tail`)
- Specify line ranges when targeting specific sections
- Request entire files unless they exceed 5,000 lines

### edit_files
- Include enough context in search blocks for uniqueness
- Preserve correct indentation and whitespace
- Never use placeholder comments like `// ... existing code...`
- Split multiple semantic changes into separate diff blocks

### run_command
- Avoid interactive or fullscreen commands
- Use non-paginated output options
- Maintain current directory using absolute paths
- Never expose secrets in plain text

## Common Tasks

### Bug Fixes
1. Identify the bug location
2. Understand the root cause
3. Implement a fix
4. Test the solution
5. Update related documentation

### Feature Implementation
1. Clarify requirements
2. Design the solution
3. Implement incrementally
4. Write tests
5. Update documentation

### Code Review
1. Check for style consistency
2. Verify logic correctness
3. Assess performance implications
4. Ensure proper error handling
5. Validate test coverage

### iOS-Specific Tasks
1. **SwiftUI View Creation**: 
   - MUST follow "Not Boring" design principles
   - Include 3D effects, gradients, and animations
   - Use custom components, not standard iOS ones
   - Add haptic feedback and micro-interactions
2. **Core Data Operations**: Ensure proper context management
3. **Widget Development**: Follow WidgetKit best practices with playful design
4. **Calendar Integration**: Use EventKit appropriately
5. **Notifications**: Configure UNUserNotificationCenter properly

### Backend-Specific Tasks
1. **API Endpoint Creation**: Follow RESTful conventions
2. **Database Migrations**: Use TypeORM migrations
3. **Authentication**: Implement JWT properly
4. **Redis Caching**: Use appropriate TTL values
5. **Docker Operations**: Ensure container compatibility

## Error Handling
- Provide helpful error messages
- Suggest solutions for common problems
- Log errors appropriately
- Handle edge cases gracefully

## Documentation
- Update README files when adding features
- Comment complex logic
- Maintain API documentation
- Document configuration changes

## Security Guidelines
- Never commit credentials
- Use secure coding practices
- Validate user input
- Handle sensitive data carefully
- Follow OWASP guidelines where applicable

## Workflow
1. **Understand**: Fully comprehend the task requirements
2. **Explore**: Investigate the codebase to understand context
3. **Plan**: Design the approach before implementation
4. **Execute**: Implement changes incrementally
5. **Validate**: Test and verify the solution
6. **Document**: Update relevant documentation
7. **Review**: Ensure all requirements are met

## Do's and Don'ts

### Do's
✅ Ask for clarification when needed
✅ Respect existing code patterns
✅ Test changes thoroughly
✅ Maintain backward compatibility when possible
✅ Document significant changes
✅ Use appropriate tools for each task
✅ Follow security best practices
✅ **UI: Make everything feel alive and reactive**
✅ **UI: Use 3D effects and shadows for depth**
✅ **UI: Add surprises and delightful micro-interactions**
✅ **UI: Implement spring animations for all transitions**
✅ **UI: Use gradients instead of flat colors**
✅ **UI: Add haptic feedback to reinforce actions**

### Don'ts
❌ Make assumptions about unclear requirements
❌ Override user modifications
❌ Execute potentially harmful commands
❌ Expose sensitive information
❌ Use deprecated practices
❌ Ignore error messages
❌ Skip testing
❌ **UI: Use standard iOS components (boring!)**
❌ **UI: Create static interfaces without animations**
❌ **UI: Use flat design without depth**
❌ **UI: Implement animations slower than 300ms**
❌ **UI: Forget haptic feedback**
❌ **UI: Ignore battery/performance states**

## Quick Reference

### Common Commands
```bash
# Git operations (always use --no-pager)
git --no-pager status
git --no-pager diff
git --no-pager log --oneline -10

# File discovery
find . -name "*.swift" -type f
find . -name "*.ts" -type f
grep -r "function_name" .

# iOS Development
xcodebuild -list -project HouseholdApp.xcodeproj
xcodebuild -scheme HouseholdApp -destination 'platform=iOS Simulator,name=iPhone 15'
xcrun simctl list devices

# Backend Development
cd /Users/Max/Roomies/roomies-backend
npm run dev         # Start development server
npm test           # Run tests
npm run build      # Build TypeScript
npm run lint       # Check code style
docker-compose up  # Start with Docker

# Database Operations
npm run migrate    # Run migrations
npm run seed       # Seed database
```

### File Path Conventions
- Relative paths for project files: `src/components/Button.js`
- Absolute paths for system files: `/etc/hosts`
- Parent directory references: `../config/settings.json`

## UI/UX Implementation - "Not Boring" Design Philosophy

### Core UI Principles (MUST FOLLOW)
The app follows the **"Not Boring Apps"** approach - think of it as a game, not a utility:

1. **3D-First Design**
   - Every element must have depth, shadows, and physical presence
   - Buttons should "float" above the interface
   - Cards need strong elevations with light effects
   - Combine Glassmorphism and Neumorphism effects

2. **Fluid Animations Everywhere**
   - EVERY interaction must be animated (prefer Spring animations)
   - Elements should "breathe" - pulse, react, feel alive
   - Transitions should be theatrical and impressive
   - Loading states are entertainment, not waiting time

3. **No Standard Components**
   - Avoid default iOS/Material components
   - Use custom shapes and organic forms
   - Buttons as 3D capsules or floating elements
   - Lists as stackable cards with physics

4. **Micro-Interactions as Core Features**
   - Haptic feedback on EVERY important action
   - Visual rewards for successes (confetti, light explosions)
   - Sound design to reinforce the game feeling
   - Gestures trigger surprising reactions

### Color Implementation

#### Primary Colors (Use These)
- **Hero Orange**: #FF6B35 (main actions)
- **Neon Blue**: #00D4FF (success, positive actions)
- **Magic Purple**: #8B5CF6 (premium features)
- **Victory Green**: #10B981 (completed tasks)

#### Gradients (Always Use)
- Orange: #FF6B35 → #FFB86C
- Blue: #00D4FF → #6366F1
- Purple: #8B5CF6 → #EC4899
- Green: #10B981 → #34D399

### Animation Standards

#### Spring Animation Settings
```swift
// Default Spring
Animation.spring(response: 0.6, dampingFraction: 0.7)

// Quick Spring
Animation.spring(response: 0.3, dampingFraction: 0.8)

// Bouncy Spring
Animation.spring(response: 0.8, dampingFraction: 0.5)
```

#### Required Animations
- **Button Press**: Scale to 0.95 with shadow reduction
- **Task Completion**: Scale pulse + confetti + haptic
- **Card Hover**: Lift with shadow increase + slight rotation
- **List Entry**: Staggered cascade effect

### 3D Component Requirements

#### Buttons MUST Have
- Gradient background
- Shadow (min 8px blur)
- Inner highlight
- Scale animation on tap
- Haptic feedback

#### Cards MUST Have
- White background with gradient overlay
- Multiple shadow layers for depth
- Border radius of 20pt minimum
- Perspective transform
- Hover/tap animations

### Typography Rules
- **Hero Text**: 42pt, Weight 800, with shadow and glow
- **Section Headers**: 32pt, Weight 700, with 3D perspective
- **Body Text**: 17pt, Weight 400, line height 1.5
- Always use SF Pro Display/Text on iOS

### Gamification Elements

#### Points Display
- 3D extruded numbers
- Gold gradient (#FFD700 → #FFA500)
- Floating animation
- Particle effects when earned

#### Progress Bars
- Liquid fill animation
- Wave motion effect
- Gradient colors
- Explosion on completion

#### Achievement Badges
- 3D medallion design
- Metallic materials with reflections
- Spinning entrance animation
- Rarity system (Bronze → Diamond)

### Performance Requirements
- **60 FPS** for all UI animations (non-negotiable)
- Max 50 particles simultaneous
- Reduce effects below 20% battery
- Support reduced motion accessibility

### Implementation Checklist for New UI
- [ ] Has 3D depth/shadow?
- [ ] Includes spring animations?
- [ ] Uses gradient colors?
- [ ] Has haptic feedback?
- [ ] Includes micro-interactions?
- [ ] Feels like a game element?
- [ ] Surprises and delights?
- [ ] Maintains 60 FPS?

## Technology-Specific Guidelines

### Swift/iOS Development
- **SwiftUI Best Practices**:
  - Use `@StateObject` for owned objects, `@ObservedObject` for passed objects
  - Prefer `@EnvironmentObject` for app-wide state
  - Use `.task` modifier for async operations
  - Follow MVVM pattern where appropriate
- **Core Data**:
  - Always use background contexts for heavy operations
  - Implement proper error handling for save operations
  - Use `NSFetchedResultsController` for list views
- **Performance**:
  - Use `Instruments` for profiling
  - Implement lazy loading for large datasets
  - Optimize image loading and caching

### TypeScript/Node.js Development
- **TypeScript Best Practices**:
  - Define proper interfaces and types
  - Use strict mode
  - Avoid `any` type unless absolutely necessary
  - Implement proper error types
- **Express.js**:
  - Use middleware for cross-cutting concerns
  - Implement proper request validation with Joi
  - Follow RESTful conventions
- **Database (PostgreSQL + TypeORM)**:
  - Use transactions for multi-step operations
  - Implement proper indexing
  - Use query builder for complex queries
- **Redis**:
  - Implement proper cache invalidation
  - Use appropriate data structures
  - Set reasonable TTL values

## Debugging Guidelines

### iOS Debugging
- Use Xcode debugger and breakpoints
- Check console output for runtime warnings
- Use `print()` statements sparingly
- Utilize SwiftUI preview for UI debugging
- Check memory graph for retain cycles

### Backend Debugging
- Use `console.log()` with proper context
- Implement structured logging with Winston
- Use Node.js debugger with VS Code
- Monitor Redis with `redis-cli`
- Check PostgreSQL logs for query issues

## Continuous Improvement
This document should be updated as the project evolves and new patterns emerge. Consider:
- Adding project-specific conventions
- Documenting discovered best practices
- Updating tool usage based on project needs
- Incorporating team feedback
- Maintaining consistency across iOS and backend codebases

## Environment Variables and Configuration

### iOS Configuration
- **Bundle Identifier**: Update in Xcode project settings
- **Signing**: Configure development team
- **Entitlements**: Check HouseholdApp.entitlements for capabilities
- **Info.plist**: Update for permissions and app configuration

### Backend Configuration
- Use `.env` file (never commit to repository)
- Required variables:
  - `DATABASE_URL`: PostgreSQL connection string
  - `REDIS_URL`: Redis connection string
  - `JWT_SECRET`: Authentication secret
  - `AWS_*`: S3 configuration for file uploads
  - `SMTP_*`: Email service configuration

## Known Issues and Workarounds

### iOS Issues
- **SwiftUI Preview**: May crash with Core Data - use mock data
- **Widget Updates**: Timeline refresh may be delayed
- **Calendar Sync**: Requires explicit permission request

### Backend Issues
- **TypeORM**: Entity loading order matters
- **Redis Connection**: May timeout in development - check Docker
- **Hot Reload**: May not work with certain TypeScript decorators

## Performance Optimization Tips

### iOS Optimization
- Use lazy loading for images
- Implement proper list virtualization
- Cache computed properties
- Use background queues for heavy operations
- Profile with Instruments regularly

### Backend Optimization
- Implement database query optimization
- Use Redis for session storage
- Enable compression middleware
- Implement proper pagination
- Use database connection pooling

## Contact and Resources
- Project Repository: `/Users/Max/Roomies`
- iOS Documentation: `/Users/Max/Roomies/documentation/`
- Backend Documentation: `/Users/Max/Roomies/roomies-backend/README.md`
- Issue Tracking: Check TODO.md for current issues
- Main App Entry: `HouseholdApp/RoomiesApp.swift`
- Backend Entry: `backend/src/server.ts`

---
*Last Updated: 2025-08-06*
*Version: 2.0.0*
