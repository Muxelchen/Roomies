## Incremental UI/UX Upgrades Log (iOS)

Date: [autofill current]

Scope: Quick, safe improvements to clarity, accessibility, motion, spacing, and performance. Each change is small, testable, and guarded for backwards compatibility.

### Shared: NotBoringButton
- Reduced default font to `.headline` with `.semibold` to improve Dynamic Type layout.
- Added `.accessibilityLabel`, `.accessibilityHint`, and `.accessibilityAddTraits(.isButton)`.
- Increased hit target via `.frame(minHeight: 44)` and `.contentShape(Capsule())`.
- Reduced shadow radius (performance + consistency).
- Gated press/glow animations behind `@Environment(\.accessibilityReduceMotion)`.

### Shared: EnhancedTextField
- Added `textContentType` and `disableAutocorrection` parameters for better input UX.
- Introduced inline validation API: `errorMessage` and `isValid` with red border state.
- Added accessibility label/hint and container semantics.

### Navigation: NotBoringTabBar
- Reduced heavy shadows and blurs for performance.
- Added accessibility on each tab item with selected state feedback.
- Gated bounce, wave, and particle effects behind Reduce Motion.

### DashboardView
- Gated overlay transitions and avatar/greeting animations behind Reduce Motion.
- Replaced repeating timer-based points pulse with a single entrance pulse.
- Added accessibility to avatar ("Edit profile") and points label ("Points: N").

### TasksView
- Gated background, overlay, and transition animations behind Reduce Motion.
- Added accessibility labels/hints to FAB and filter chips.
- Preserved existing swipe actions; no behavior changes.

### Rationale/Impact
- Accessibility: VoiceOver coverage for icon-only controls; larger hit targets; Reduced Motion respected.
- Visual: Softer shadows, consistent typography reduce clutter and clipping at large sizes.
- Performance: Fewer concurrent effects, no repeat-forever animations in shared components.

### Test Notes
1) Build and run on simulator (any recent iPhone).
2) Toggle Settings > Accessibility > Motion > Reduce Motion to verify static fallbacks.
3) VoiceOver: navigate tab bar and primary buttons to confirm labels/hints.
4) Dynamic Type: large sizes should not clip button titles or field labels.

All changes are backward compatible and scoped to shared components or view-local modifiers.


