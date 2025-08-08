Roomies Premium Design System
================================

Tokens
- Spacing: `Spacing.nano(4)`, `micro(8)`, `small(12)`, `medium(16)`, `large(20)`
- Corners: `CornerRadius.small(12)`, `medium(20)`, `large(25)`
- Sections/Colors: `SectionColor`: dashboard(blue), tasks(green), store(purple), challenges(orange), leaderboard(red), profile(indigo), settings(teal)
- Typography: `.heroTitle`, `.pageTitle`, `.sectionHeader`, `.cardTitle`, `.body`, `.caption`, `.micro` (all .rounded)
- Shadows: `.subtle`, `.medium`, `.prominent`, `.glow(color)`
- Animations: `.microInteraction`, `.stateChange`, `.entrance`, `.exit`

Components and Modifiers
- `PremiumScreenBackground(sectionColor:style:)`: gradient + glass morphism background
- `premiumStyle(sectionColor:cornerRadius:shadowStyle:spacing:)`: wraps content in glass card with spacing and glow
- `PremiumCard { ... }`: card container using tokens
- `PremiumButton(title, icon:, sectionColor:, action)`: gradient, glow, haptics/audio built-in
- `PremiumTextField(title, icon, text:, sectionColor)`
- `premiumText(_:)`: apply typography
- `premiumEntrance(delay:)`: entrance animation
- `premiumSwipeGestures(...)`: swipe/long-press gestures with haptics
- `premiumListAppearance()` / `premiumFormAppearance()`: hide default backgrounds and standardize list/form

Interactives (with haptics + audio)
- `PremiumToggleStyle(tint:)`: 52x30, 44pt min hit area, VoiceOver traits, plays toggleOn/off
- `PremiumPressButtonStyle()`: scale on press, 44pt min hit, plays light tap

Accessibility
- Always use `.minTappableArea()` on custom hit targets
- Use `.accessibilityHeader()` for section headers
- Provide `.accessibilityLabel`/`.accessibilityHint` for interactive elements
- Respect Reduce Motion; keep animations short and single-pass

Audio & Haptics
- Central manager: `PremiumAudioHapticSystem`
- Quick helpers: `playButtonTap(style:)`, `playModalPresent()`, `playModalDismiss()`, `playSuccess()`, `playError()`
- Contexts and sequences for tasks, level-ups, challenges, refresh, etc.

Usage Cheatsheet
```swift
// Toggle
Toggle("", isOn: $enabled)
  .toggleStyle(PremiumToggleStyle(tint: PremiumDesignSystem.SectionColor.settings.primary))

// Button
Button("Save") { PremiumAudioHapticSystem.playButtonTap(style: .medium) }
  .buttonStyle(PremiumPressButtonStyle())

// Form
Form { ... }.premiumFormAppearance()

// Header
Text("Settings").premiumText(.sectionHeader).accessibilityHeader()
```

Conventions
- Never use `PlainButtonStyle` for tappable elements unless you wrap with `PremiumPressButtonStyle` on a higher container.
- All destructive or major actions should also call a relevant audio/haptic (e.g., `playError`, heavy tap).
- Keep edge cases in mind: dynamic type fits, landscape spacing, iPad widths.


