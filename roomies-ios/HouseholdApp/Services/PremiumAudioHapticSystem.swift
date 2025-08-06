import Foundation
import AVFoundation
import UIKit
import SwiftUI
import Combine

// MARK: - 🎵 PREMIUM AUDIO & HAPTIC EXPERIENCE SYSTEM 🎵
// This system transforms your Roomies app into a luxurious, engaging sensory masterpiece
// Every interaction feels premium, rewarding, and addictive through masterful audio-haptic design

@MainActor
class PremiumAudioHapticSystem: ObservableObject {
    static let shared = PremiumAudioHapticSystem()
    
    // MARK: - 🔊 Core Audio Infrastructure
    private var audioEngine = AVAudioEngine()
    private var audioPlayers: [AudioAssetType: AVAudioPlayer] = [:]
    private var ambientPlayer: AVAudioPlayer?
    private var musicPlayer: AVAudioPlayer?
    
    // MARK: - 🎚️ Audio Settings & State
    @Published var masterVolume: Float = 1.0
    @Published var effectsVolume: Float = 0.85
    @Published var musicVolume: Float = 0.4
    @Published var ambientVolume: Float = 0.3
    @Published var isAudioEnabled = true
    @Published var isHapticEnabled = true
    @Published var currentTheme: AudioTheme = .roomiesClassic
    
    // MARK: - 🎭 Premium Audio Themes
    enum AudioTheme: String, CaseIterable, Identifiable {
        case roomiesClassic = "Roomies Classic"
        case minimalistZen = "Minimalist Zen"
        case gamemaster = "Gamemaster"
        case luxuryLounge = "Luxury Lounge"
        case retroArcade = "Retro Arcade"
        case naturalSounds = "Natural Sounds"
        
        var id: String { rawValue }
        
        var description: String {
            switch self {
            case .roomiesClassic:
                return "Warm, friendly tones perfect for household harmony"
            case .minimalistZen:
                return "Clean, calming sounds for focused productivity"
            case .gamemaster:
                return "Epic gaming-inspired audio with powerful rewards"
            case .luxuryLounge:
                return "Sophisticated, premium sounds for elevated experiences"
            case .retroArcade:
                return "Nostalgic 8-bit inspired chiptune audio effects"
            case .naturalSounds:
                return "Organic, nature-inspired audio for peaceful living"
            }
        }
        
        var ambientTrack: String? {
            switch self {
            case .roomiesClassic: return "roomies_ambient_warm"
            case .minimalistZen: return "zen_ambient_flow"
            case .gamemaster: return "epic_ambient_quest"
            case .luxuryLounge: return "luxury_ambient_lounge"
            case .retroArcade: return nil // No ambient for retro
            case .naturalSounds: return "nature_ambient_forest"
            }
        }
    }
    
    // MARK: - 🎼 Comprehensive Audio Asset Types
    enum AudioAssetType: String, CaseIterable {
        // 🏠 DASHBOARD INTERACTIONS
        case dashboardOpen = "dashboard_open"
        case householdSwitch = "household_switch"
        case statTileFlip = "stat_tile_flip"
        case progressBarFill = "progress_bar_fill"
        case weatherUpdate = "weather_update"
        
        // ✅ TASK MANAGEMENT
        case taskCreate = "task_create"
        case taskEdit = "task_edit"
        case taskComplete = "task_complete"
        case taskDelete = "task_delete"
        case taskAssign = "task_assign"
        case taskDueReminder = "task_due_reminder"
        case taskOverdue = "task_overdue"
        case bulkTaskComplete = "bulk_task_complete"
        
        // 🎯 CHALLENGES & ACHIEVEMENTS  
        case challengeCreate = "challenge_create"
        case challengeJoin = "challenge_join"
        case challengeProgress = "challenge_progress"
        case challengeComplete = "challenge_complete"
        case challengeWin = "challenge_win"
        case challengeFailed = "challenge_failed"
        case streakMilestone = "streak_milestone"
        
        // 🏆 GAMIFICATION & REWARDS
        case pointsEarned = "points_earned"
        case pointsSpent = "points_spent"
        case levelUp = "level_up"
        case badgeEarned = "badge_earned"
        case achievementUnlocked = "achievement_unlocked"
        case leaderboardClimb = "leaderboard_climb"
        case leaderboardTop = "leaderboard_top"
        case rewardRedeemed = "reward_redeemed"
        case bonusMultiplier = "bonus_multiplier"
        
        // 🎪 CELEBRATION SEQUENCES
        case miniCelebration = "mini_celebration"
        case mediumCelebration = "medium_celebration"
        case epicCelebration = "epic_celebration"
        case confettiPop = "confetti_pop"
        case fireworksBurst = "fireworks_burst"
        
        // 🧭 NAVIGATION & UI
        case tabSwitch = "tab_switch"
        case buttonTapLight = "button_tap_light"
        case buttonTapMedium = "button_tap_medium"
        case buttonTapHeavy = "button_tap_heavy"
        case toggleOn = "toggle_on"
        case toggleOff = "toggle_off"
        case modalOpen = "modal_open"
        case modalClose = "modal_close"
        case pageTransition = "page_transition"
        case pullRefresh = "pull_refresh"
        case swipeAction = "swipe_action"
        
        // 👥 SOCIAL & HOUSEHOLD
        case memberJoined = "member_joined"
        case memberLeft = "member_left"
        case householdCreated = "household_created"
        case inviteSent = "invite_sent"
        case messageReceived = "message_received"
        case encouragementCheer = "encouragement_cheer"
        
        // 📱 NOTIFICATIONS & ALERTS
        case notificationGentle = "notification_gentle"
        case notificationUrgent = "notification_urgent"
        case notificationSuccess = "notification_success"
        case alertWarning = "alert_warning"
        case alertError = "alert_error"
        case reminderChime = "reminder_chime"
        
        // 💎 PREMIUM MICRO-INTERACTIONS
        case cardFlipOver = "card_flip_over"
        case cardFlipBack = "card_flip_back"
        case drawerSlide = "drawer_slide"
        case zoomIn = "zoom_in"
        case zoomOut = "zoom_out"
        case sparkleChime = "sparkle_chime"
        case magicalWhoosh = "magical_whoosh"
        case premiumClick = "premium_click"
        
        // 🎵 LOADING & TRANSITIONS
        case appLaunch = "app_launch"
        case loadingStart = "loading_start"
        case loadingComplete = "loading_complete"
        case dataSync = "data_sync"
        case errorRecovery = "error_recovery"
        case connectionLost = "connection_lost"
        case connectionRestored = "connection_restored"
        
        // 📊 STORE & REWARDS
        case storeOpen = "store_open"
        case itemPreview = "item_preview"
        case purchaseConfirm = "purchase_confirm"
        case purchaseSuccess = "purchase_success"
        case insufficientFunds = "insufficient_funds"
        case rewardUnlock = "reward_unlock"
        
        var fileName: String {
            return "roomies_\(rawValue)"
        }
        
        var category: AudioCategory {
            switch self {
            case .dashboardOpen, .householdSwitch, .statTileFlip, .progressBarFill, .weatherUpdate:
                return .dashboard
            case .taskCreate, .taskEdit, .taskComplete, .taskDelete, .taskAssign, .taskDueReminder, .taskOverdue, .bulkTaskComplete:
                return .tasks
            case .challengeCreate, .challengeJoin, .challengeProgress, .challengeComplete, .challengeWin, .challengeFailed, .streakMilestone:
                return .challenges
            case .pointsEarned, .pointsSpent, .levelUp, .badgeEarned, .achievementUnlocked, .leaderboardClimb, .leaderboardTop, .rewardRedeemed, .bonusMultiplier:
                return .gamification
            case .miniCelebration, .mediumCelebration, .epicCelebration, .confettiPop, .fireworksBurst:
                return .celebrations
            case .tabSwitch, .buttonTapLight, .buttonTapMedium, .buttonTapHeavy, .toggleOn, .toggleOff, .modalOpen, .modalClose, .pageTransition, .pullRefresh, .swipeAction:
                return .navigation
            case .memberJoined, .memberLeft, .householdCreated, .inviteSent, .messageReceived, .encouragementCheer:
                return .social
            case .notificationGentle, .notificationUrgent, .notificationSuccess, .alertWarning, .alertError, .reminderChime:
                return .notifications
            case .cardFlipOver, .cardFlipBack, .drawerSlide, .zoomIn, .zoomOut, .sparkleChime, .magicalWhoosh, .premiumClick:
                return .microInteractions
            case .appLaunch, .loadingStart, .loadingComplete, .dataSync, .errorRecovery, .connectionLost, .connectionRestored:
                return .system
            case .storeOpen, .itemPreview, .purchaseConfirm, .purchaseSuccess, .insufficientFunds, .rewardUnlock:
                return .store
            }
        }
    }
    
    enum AudioCategory: String, CaseIterable {
        case dashboard, tasks, challenges, gamification, celebrations
        case navigation, social, notifications, microInteractions, system, store
        
        var volume: Float {
            switch self {
            case .celebrations, .gamification: return 0.9
            case .notifications, .system: return 0.8
            case .microInteractions, .navigation: return 0.6
            case .tasks, .challenges: return 0.7
            case .dashboard, .social, .store: return 0.75
            }
        }
    }
    
    // MARK: - 📳 Advanced Haptic Patterns
    enum HapticPattern: String, CaseIterable {
        // Basic patterns
        case tap = "tap"
        case lightTap = "light_tap"
        case mediumTap = "medium_tap"
        case heavyTap = "heavy_tap"
        
        // Success patterns  
        case successSingle = "success_single"
        case successDouble = "success_double"
        case successTriple = "success_triple"
        case celebration = "celebration"
        case epicWin = "epic_win"
        
        // Progress patterns
        case progressTick = "progress_tick"
        case levelUp = "level_up"
        case achievementPop = "achievement_pop"
        case streakBonus = "streak_bonus"
        
        // Navigation patterns
        case tabChange = "tab_change"
        case modalPresent = "modal_present"
        case modalDismiss = "modal_dismiss"
        case pageFlip = "page_flip"
        
        // Error & warning patterns
        case error = "error"
        case warning = "warning"
        case denied = "denied"
        case correction = "correction"
        
        // Social patterns
        case notification = "notification"
        case message = "message"
        case encouragement = "encouragement"
        case highFive = "high_five"
        
        // Premium patterns (complex sequences)
        case heartbeat = "heartbeat"
        case drumroll = "drumroll"
        case fanfare = "fanfare"
        case powerup = "powerup"
    }
    
    // MARK: - 🎪 Audio Event Context
    struct AudioContext {
        let intensity: Float // 0.0 to 1.0
        let urgency: Float   // 0.0 to 1.0
        let celebration: Float // 0.0 to 1.0
        let delay: TimeInterval
        let hapticPattern: HapticPattern?
        let visualEffect: VisualEffectType?
        
        static let `default` = AudioContext(
            intensity: 0.5,
            urgency: 0.0,
            celebration: 0.0,
            delay: 0.0,
            hapticPattern: nil,
            visualEffect: nil
        )
        
        static let subtle = AudioContext(
            intensity: 0.3,
            urgency: 0.0,
            celebration: 0.0,
            delay: 0.0,
            hapticPattern: .lightTap,
            visualEffect: nil
        )
        
        static let premium = AudioContext(
            intensity: 0.8,
            urgency: 0.0,
            celebration: 0.0,
            delay: 0.0,
            hapticPattern: .mediumTap,
            visualEffect: .premiumGlow
        )
        
        static let celebration = AudioContext(
            intensity: 1.0,
            urgency: 0.0,
            celebration: 1.0,
            delay: 0.0,
            hapticPattern: .celebration,
            visualEffect: .confetti
        )
        
        static let urgent = AudioContext(
            intensity: 0.9,
            urgency: 1.0,
            celebration: 0.0,
            delay: 0.0,
            hapticPattern: .warning,
            visualEffect: .pulseRed
        )
    }
    
    enum VisualEffectType {
        case premiumGlow, confetti, sparkles, pulseBlue, pulseRed, ripple, zoom
    }
    
    // MARK: - 🎯 Initialization
    private init() {
        setupAudioEngine()
        loadUserPreferences()
        preloadCriticalAudioAssets()
        setupAudioSessionHandling()
        startAmbientSoundscape()
        
        // Log initialization for debugging
        LoggingManager.shared.info("PremiumAudioHapticSystem initialized", category: "audio")
    }
    
    private func setupAudioEngine() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            LoggingManager.shared.error("Audio session setup failed: \(error)", category: "audio")
        }
    }
    
    private func loadUserPreferences() {
        // Use UserDefaults.standard for consistency
        isAudioEnabled = UserDefaults.standard.bool(forKey: "premiumAudioEnabled")
        isHapticEnabled = UserDefaults.standard.bool(forKey: "premiumHapticEnabled")
        
        let savedMasterVolume = UserDefaults.standard.object(forKey: "masterVolume") as? Float
        masterVolume = savedMasterVolume ?? 1.0
        
        let savedEffectsVolume = UserDefaults.standard.object(forKey: "effectsVolume") as? Float
        effectsVolume = savedEffectsVolume ?? 0.85
        
        let savedMusicVolume = UserDefaults.standard.object(forKey: "musicVolume") as? Float
        musicVolume = savedMusicVolume ?? 0.4
        
        let savedAmbientVolume = UserDefaults.standard.object(forKey: "ambientVolume") as? Float
        ambientVolume = savedAmbientVolume ?? 0.3
        
        if let themeString = UserDefaults.standard.string(forKey: "audioTheme"),
           let theme = AudioTheme(rawValue: themeString) {
            currentTheme = theme
        }
    }
    
    private func preloadCriticalAudioAssets() {
        let criticalAssets: [AudioAssetType] = [
            .buttonTapLight, .buttonTapMedium, .taskComplete, .pointsEarned,
            .tabSwitch, .modalOpen, .modalClose, .notificationGentle,
            .achievementUnlocked, .levelUp
        ]
        
        for asset in criticalAssets {
            preloadAudioAsset(asset)
        }
    }
    
    private func preloadAudioAsset(_ asset: AudioAssetType) {
        // In production: load actual audio files from bundle
        // For demo: use system sound mapping
    }
    
    private func setupAudioSessionHandling() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                self.handleAudioInterruption()
            }
        }
    }
    
    private func handleAudioInterruption() {
        // Handle phone calls, other app interruptions gracefully
        ambientPlayer?.pause()
        musicPlayer?.pause()
    }
    
    // MARK: - 🎵 Premium Audio Playback System
    
    /// Master audio playback method - handles all audio with context-aware intelligence
    func play(_ asset: AudioAssetType, context: AudioContext = .default) {
        guard isAudioEnabled else { return }
        
        let finalVolume = calculateContextualVolume(for: asset, context: context)
        let delay = context.delay
        
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.executeAudioPlayback(asset, volume: finalVolume, context: context)
            }
        } else {
            executeAudioPlayback(asset, volume: finalVolume, context: context)
        }
        
        // Trigger coordinated haptic feedback
        if let hapticPattern = context.hapticPattern {
            triggerHaptic(hapticPattern, delay: delay)
        }
        
        // Trigger visual effects
        if let visualEffect = context.visualEffect {
            triggerVisualEffect(visualEffect, delay: delay)
        }
        
        // Log for analytics
        logAudioEvent(asset, context: context)
    }
    
    private func executeAudioPlayback(_ asset: AudioAssetType, volume: Float, context: AudioContext) {
        // For now, use system sounds with enhanced mapping
        let systemSoundID = mapAssetToSystemSound(asset, theme: currentTheme)
        AudioServicesPlaySystemSound(systemSoundID)
        
        // In production: Use AVAudioPlayer with pitch, reverb, and effects
        // if let player = audioPlayers[asset] {
        //     player.volume = volume
        //     player.rate = calculatePlaybackRate(for: context)
        //     player.play()
        // }
    }
    
    private func calculateContextualVolume(for asset: AudioAssetType, context: AudioContext) -> Float {
        let baseVolume = asset.category.volume
        let intensityMultiplier = 0.5 + (context.intensity * 0.5) // 0.5 to 1.0
        let celebrationBoost = context.celebration * 0.3 // Up to +30%
        let urgencyBoost = context.urgency * 0.2 // Up to +20%
        
        return min(1.0, baseVolume * intensityMultiplier + celebrationBoost + urgencyBoost) * effectsVolume * masterVolume
    }
    
    // MARK: - 🎼 Pre-designed Audio Sequences
    
    func playTaskCompletionSequence(points: Int, isStreak: Bool = false, isMilestone: Bool = false) {
        if isMilestone {
            playSequence(.epicTaskMilestone)
        } else if isStreak {
            playSequence(.streakTaskComplete)
        } else if points >= 50 {
            playSequence(.highValueTaskComplete)
        } else {
            play(.taskComplete, context: .premium)
        }
    }
    
    func playLevelUpCelebration(newLevel: Int, isFirst: Bool = false) {
        if newLevel % 10 == 0 { // Major milestone
            playSequence(.majorLevelMilestone)
        } else if isFirst {
            playSequence(.firstLevelUp)
        } else {
            playSequence(.standardLevelUp)
        }
    }
    
    func playChallengeVictoryFanfare(difficulty: String, wasClose: Bool = false) {
        switch difficulty.lowercased() {
        case "epic", "legendary":
            playSequence(.epicChallenge)
        case "hard":
            playSequence(.hardChallenge)
        case "medium":
            playSequence(.mediumChallenge)
        default:
            playSequence(.easyChallenge)
        }
    }
    
    func playDashboardWelcome(timeOfDay: String, hasUrgentTasks: Bool = false) {
        if hasUrgentTasks {
            play(.dashboardOpen, context: .urgent)
        } else {
            let welcomeContext = AudioContext(
                intensity: 0.6,
                urgency: 0.0,
                celebration: 0.0,
                delay: 0.1,
                hapticPattern: .lightTap,
                visualEffect: .premiumGlow
            )
            play(.dashboardOpen, context: welcomeContext)
        }
    }
    
    // MARK: - 📳 Advanced Haptic System
    
    private func triggerHaptic(_ pattern: HapticPattern, delay: TimeInterval = 0.0) {
        guard isHapticEnabled else { return }
        
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.executeHapticPattern(pattern)
            }
        } else {
            executeHapticPattern(pattern)
        }
    }
    
    private func executeHapticPattern(_ pattern: HapticPattern) {
        switch pattern {
        case .tap, .lightTap:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            
        case .mediumTap:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            
        case .heavyTap:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            
        case .successSingle:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            
        case .successDouble:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                generator.notificationOccurred(.success)
            }
            
        case .successTriple:
            let generator = UINotificationFeedbackGenerator()
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                    generator.notificationOccurred(.success)
                }
            }
            
        case .celebration:
            // Complex celebration pattern
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            let notification = UINotificationFeedbackGenerator()
            
            impact.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                notification.notificationOccurred(.success)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                impact.impactOccurred(intensity: 0.8)
            }
            
        case .epicWin:
            // Ultimate celebration haptic sequence
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            let notification = UINotificationFeedbackGenerator()
            
            // Initial burst
            impact.impactOccurred(intensity: 1.0)
            
            // Rapid fire sequence
            for i in 1...5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                    impact.impactOccurred(intensity: CGFloat(6 - i) * 0.2)
                }
            }
            
            // Final triumph
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                notification.notificationOccurred(.success)
            }
            
        case .levelUp:
            // Rising intensity pattern
            let impact = UIImpactFeedbackGenerator(style: .medium)
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                    let intensity = 0.4 + (CGFloat(i) * 0.2)
                    impact.impactOccurred(intensity: intensity)
                }
            }
            
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            
        case .tabChange:
            UISelectionFeedbackGenerator().selectionChanged()
            
        case .heartbeat:
            // Rhythmic heartbeat pattern
            let impact = UIImpactFeedbackGenerator(style: .medium)
            let pattern = [0.0, 0.15, 0.6, 0.75] // Heart rhythm
            for delay in pattern {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    impact.impactOccurred(intensity: 0.6)
                }
            }
            
        default:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
    
    // MARK: - 🎭 Audio Theme System
    
    func setAudioTheme(_ theme: AudioTheme, animated: Bool = true) {
        let oldTheme = currentTheme
        currentTheme = theme
        
        UserDefaults.standard.set(theme.rawValue, forKey: "audioTheme")
        
        if animated {
            play(.premiumClick, context: .premium)
        }
        
        // Smoothly transition ambient soundscape
        if oldTheme.ambientTrack != theme.ambientTrack {
            transitionAmbientSoundscape(to: theme)
        }
        
        objectWillChange.send()
        LoggingManager.shared.info("Audio theme changed to: \(theme.rawValue)", category: "audio")
    }
    
    private func transitionAmbientSoundscape(to theme: AudioTheme) {
        // Fade out current ambient
        ambientPlayer?.setVolume(0, fadeDuration: 1.0)
        
        // Start new ambient after fade
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.startAmbientSoundscape()
        }
    }
    
    private func startAmbientSoundscape() {
        guard currentTheme.ambientTrack != nil else {
            ambientPlayer?.stop()
            return
        }
        
        // In production: load actual ambient audio files
        // For demo: use subtle background processing
        
        ambientPlayer?.volume = ambientVolume * masterVolume
        ambientPlayer?.numberOfLoops = -1
        ambientPlayer?.play()
    }
    
    // MARK: - 🔄 Pre-built Audio Sequences
    
    private func playSequence(_ sequence: PredefinedSequence) {
        switch sequence {
        case .standardLevelUp:
            play(.levelUp, context: .celebration)
            play(.achievementUnlocked, context: AudioContext(intensity: 0.7, urgency: 0, celebration: 0.8, delay: 0.3, hapticPattern: .achievementPop, visualEffect: .sparkles))
            play(.pointsEarned, context: AudioContext(intensity: 0.5, urgency: 0, celebration: 0.3, delay: 0.6, hapticPattern: nil, visualEffect: nil))
            
        case .majorLevelMilestone:
            play(.epicCelebration, context: .celebration)
            play(.levelUp, context: AudioContext(intensity: 1.0, urgency: 0, celebration: 1.0, delay: 0.2, hapticPattern: .epicWin, visualEffect: .confetti))
            play(.achievementUnlocked, context: AudioContext(intensity: 0.9, urgency: 0, celebration: 1.0, delay: 0.5, hapticPattern: nil, visualEffect: .sparkles))
            play(.bonusMultiplier, context: AudioContext(intensity: 0.8, urgency: 0, celebration: 0.7, delay: 0.8, hapticPattern: .celebration, visualEffect: nil))
            
        case .firstLevelUp:
            play(.confettiPop, context: .default)
            play(.levelUp, context: AudioContext(intensity: 0.9, urgency: 0, celebration: 0.9, delay: 0.2, hapticPattern: .celebration, visualEffect: .confetti))
            play(.encouragementCheer, context: AudioContext(intensity: 0.7, urgency: 0, celebration: 0.5, delay: 0.5, hapticPattern: .highFive, visualEffect: nil))
            
        case .highValueTaskComplete:
            play(.taskComplete, context: .premium)
            play(.pointsEarned, context: AudioContext(intensity: 0.8, urgency: 0, celebration: 0.6, delay: 0.2, hapticPattern: .successDouble, visualEffect: .sparkles))
            play(.sparkleChime, context: AudioContext(intensity: 0.6, urgency: 0, celebration: 0.4, delay: 0.4, hapticPattern: nil, visualEffect: .premiumGlow))
            
        case .streakTaskComplete:
            play(.taskComplete, context: .premium)
            play(.streakMilestone, context: AudioContext(intensity: 0.9, urgency: 0, celebration: 0.8, delay: 0.15, hapticPattern: .successTriple, visualEffect: .sparkles))
            play(.bonusMultiplier, context: AudioContext(intensity: 0.7, urgency: 0, celebration: 0.5, delay: 0.4, hapticPattern: nil, visualEffect: nil))
            
        case .epicTaskMilestone:
            play(.epicCelebration, context: .celebration)
            play(.taskComplete, context: AudioContext(intensity: 1.0, urgency: 0, celebration: 1.0, delay: 0.1, hapticPattern: .epicWin, visualEffect: .confetti))
            play(.achievementUnlocked, context: AudioContext(intensity: 0.9, urgency: 0, celebration: 1.0, delay: 0.4, hapticPattern: nil, visualEffect: .sparkles))
            play(.fireworksBurst, context: AudioContext(intensity: 1.0, urgency: 0, celebration: 1.0, delay: 0.7, hapticPattern: .fanfare, visualEffect: .confetti))
            
        case .epicChallenge:
            play(.challengeWin, context: .celebration)
            play(.epicCelebration, context: AudioContext(intensity: 1.0, urgency: 0, celebration: 1.0, delay: 0.2, hapticPattern: .epicWin, visualEffect: .confetti))
            play(.leaderboardTop, context: AudioContext(intensity: 0.9, urgency: 0, celebration: 0.9, delay: 0.5, hapticPattern: .fanfare, visualEffect: .sparkles))
            
        case .hardChallenge:
            play(.challengeComplete, context: .premium)
            play(.achievementUnlocked, context: AudioContext(intensity: 0.8, urgency: 0, celebration: 0.7, delay: 0.3, hapticPattern: .celebration, visualEffect: .sparkles))
            
        case .mediumChallenge:
            play(.challengeComplete, context: .default)
            play(.pointsEarned, context: AudioContext(intensity: 0.6, urgency: 0, celebration: 0.4, delay: 0.2, hapticPattern: .successDouble, visualEffect: nil))
            
        case .easyChallenge:
            play(.challengeComplete, context: .subtle)
            play(.sparkleChime, context: AudioContext(intensity: 0.4, urgency: 0, celebration: 0.2, delay: 0.1, hapticPattern: .successSingle, visualEffect: nil))
        }
    }
    
    enum PredefinedSequence {
        case standardLevelUp, majorLevelMilestone, firstLevelUp
        case highValueTaskComplete, streakTaskComplete, epicTaskMilestone
        case epicChallenge, hardChallenge, mediumChallenge, easyChallenge
    }
    
    // MARK: - 🎨 Visual Effect Coordination
    
    private func triggerVisualEffect(_ effect: VisualEffectType, delay: TimeInterval = 0.0) {
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.executeVisualEffect(effect)
            }
        } else {
            executeVisualEffect(effect)
        }
    }
    
    private func executeVisualEffect(_ effect: VisualEffectType) {
        // Post notification for UI components to respond with visual effects
        NotificationCenter.default.post(
            name: NSNotification.Name("PremiumAudioVisualEffect"),
            object: nil,
            userInfo: ["effect": effect]
        )
    }
    
    // MARK: - 🔊 System Sound Mapping
    
    private func mapAssetToSystemSound(_ asset: AudioAssetType, theme: AudioTheme) -> SystemSoundID {
        // Enhanced system sound mapping based on asset type and theme
        switch asset {
        case .taskComplete:
            return theme == .retroArcade ? 1057 : 1025
        case .levelUp:
            return theme == .gamemaster ? 1023 : 1027
        case .pointsEarned:
            return 1106
        case .achievementUnlocked:
            return 1013
        case .buttonTapLight:
            return 1104
        case .buttonTapMedium:
            return 1103
        case .buttonTapHeavy:
            return 1102
        case .tabSwitch:
            return 1103
        case .modalOpen:
            return 1024
        case .modalClose:
            return 1025
        case .notificationGentle:
            return 1002
        case .notificationUrgent:
            return 1005
        case .alertError:
            return 1053
        case .alertWarning:
            return 1006
        case .epicCelebration:
            return 1016
        case .confettiPop:
            return 1057
        case .sparkleChime:
            return 1023
        case .magicalWhoosh:
            return 1025
        case .premiumClick:
            return 1104
        default:
            return 1104 // Default click sound
        }
    }
    
    // MARK: - ⚙️ Settings & Preferences
    
    func updateMasterVolume(_ volume: Float) {
        masterVolume = max(0.0, min(1.0, volume))
        UserDefaults.standard.set(masterVolume, forKey: "masterVolume")
        updateAllPlayerVolumes()
        objectWillChange.send()
    }
    
    func updateEffectsVolume(_ volume: Float) {
        effectsVolume = max(0.0, min(1.0, volume))
        UserDefaults.standard.set(effectsVolume, forKey: "effectsVolume")
        updateAllPlayerVolumes()
        objectWillChange.send()
    }
    
    func updateMusicVolume(_ volume: Float) {
        musicVolume = max(0.0, min(1.0, volume))
        UserDefaults.standard.set(musicVolume, forKey: "musicVolume")
        musicPlayer?.volume = musicVolume * masterVolume
        objectWillChange.send()
    }
    
    func updateAmbientVolume(_ volume: Float) {
        ambientVolume = max(0.0, min(1.0, volume))
        UserDefaults.standard.set(ambientVolume, forKey: "ambientVolume")
        ambientPlayer?.volume = ambientVolume * masterVolume
        objectWillChange.send()
    }
    
    func setAudioEnabled(_ enabled: Bool) {
        isAudioEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "premiumAudioEnabled")
        
        if !enabled {
            stopAllAudio()
        } else {
            startAmbientSoundscape()
        }
        objectWillChange.send()
        LoggingManager.shared.info("Audio enabled: \(enabled)", category: "audio")
    }
    
    func setHapticEnabled(_ enabled: Bool) {
        isHapticEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "premiumHapticEnabled")
        objectWillChange.send()
        LoggingManager.shared.info("Haptic enabled: \(enabled)", category: "audio")
    }
    
    private func updateAllPlayerVolumes() {
        for (_, player) in audioPlayers {
            player.volume = effectsVolume * masterVolume
        }
        musicPlayer?.volume = musicVolume * masterVolume
        ambientPlayer?.volume = ambientVolume * masterVolume
    }
    
    private func stopAllAudio() {
        for (_, player) in audioPlayers {
            player.stop()
        }
        musicPlayer?.stop()
        ambientPlayer?.stop()
    }
    
    // MARK: - 📊 Analytics & Insights
    
    private var audioEventCount = 0
    private var lastAudioEvent = Date()
    
    func logAudioEvent(_ asset: AudioAssetType, context: AudioContext) {
        audioEventCount += 1
        lastAudioEvent = Date()
        
        // Use your existing analytics system
        AnalyticsManager.shared.trackAudioEvent(
            asset: asset.rawValue,
            intensity: context.intensity,
            theme: currentTheme.rawValue
        )
    }
    
    func getAudioUsageStats() -> (eventCount: Int, lastEvent: Date, isHealthy: Bool) {
        let isHealthy = isAudioEnabled && isHapticEnabled && masterVolume > 0.1
        return (audioEventCount, lastAudioEvent, isHealthy)
    }
}

// MARK: - 🛠️ Convenience Extensions

extension PremiumAudioHapticSystem {
    
    // Quick access methods for common actions
    static func playTaskComplete(points: Int = 10, isStreak: Bool = false, isMilestone: Bool = false) {
        shared.playTaskCompletionSequence(points: points, isStreak: isStreak, isMilestone: isMilestone)
    }
    
    static func playLevelUp(newLevel: Int, isFirst: Bool = false) {
        shared.playLevelUpCelebration(newLevel: newLevel, isFirst: isFirst)
    }
    
    static func playButtonTap(style: ButtonTapStyle = .medium) {
        let asset: AudioAssetType = style == .light ? .buttonTapLight : style == .heavy ? .buttonTapHeavy : .buttonTapMedium
        shared.play(asset, context: .subtle)
    }
    
    static func playTabSwitch() {
        shared.play(.tabSwitch, context: AudioContext(intensity: 0.4, urgency: 0, celebration: 0, delay: 0, hapticPattern: .tabChange, visualEffect: nil))
    }
    
    static func playModalPresent() {
        shared.play(.modalOpen, context: AudioContext(intensity: 0.6, urgency: 0, celebration: 0, delay: 0, hapticPattern: .modalPresent, visualEffect: .premiumGlow))
    }
    
    static func playModalDismiss() {
        shared.play(.modalClose, context: AudioContext(intensity: 0.4, urgency: 0, celebration: 0, delay: 0, hapticPattern: .modalDismiss, visualEffect: nil))
    }
    
    static func playError() {
        shared.play(.alertError, context: AudioContext(intensity: 0.8, urgency: 0.9, celebration: 0, delay: 0, hapticPattern: .error, visualEffect: .pulseRed))
    }
    
    static func playSuccess() {
        shared.play(.notificationSuccess, context: AudioContext(intensity: 0.7, urgency: 0, celebration: 0.5, delay: 0, hapticPattern: .successSingle, visualEffect: .sparkles))
    }
    
    // MARK: - Context-aware methods for enhanced interactions
    
    static func playTaskComplete(context: TaskContext) {
        switch context {
        case .taskCompletion:
            shared.play(.taskComplete, context: AudioContext(intensity: 0.8, urgency: 0, celebration: 0.6, delay: 0, hapticPattern: .successSingle, visualEffect: .sparkles))
        }
    }
    
    static func playError(context: ErrorContext) {
        switch context {
        case .systemError:
            shared.play(.alertError, context: AudioContext(intensity: 0.8, urgency: 0.9, celebration: 0, delay: 0, hapticPattern: .error, visualEffect: .pulseRed))
        }
    }
    
    static func playSuccess(context: SuccessContext) {
        switch context {
        case .taskRefreshComplete:
            shared.play(.notificationSuccess, context: AudioContext(intensity: 0.6, urgency: 0, celebration: 0.3, delay: 0, hapticPattern: .successSingle, visualEffect: nil))
        }
    }
    
    static func playFilterSwitch(context: FilterContext) {
        switch context {
        case .taskFilterChange:
            shared.play(.tabSwitch, context: AudioContext(intensity: 0.4, urgency: 0, celebration: 0, delay: 0, hapticPattern: .tabChange, visualEffect: nil))
        }
    }
    
    static func playPullToRefresh(context: RefreshContext) {
        switch context {
        case .taskRefreshStart:
            shared.play(.pullRefresh, context: AudioContext(intensity: 0.5, urgency: 0, celebration: 0, delay: 0, hapticPattern: .lightTap, visualEffect: nil))
        }
    }
    
    static func playTaskInteraction(context: TaskInteractionContext) {
        switch context {
        case .taskButtonPress:
            shared.play(.buttonTapMedium, context: AudioContext(intensity: 0.6, urgency: 0, celebration: 0, delay: 0, hapticPattern: .mediumTap, visualEffect: nil))
        }
    }
    
    static func playButtonPress(context: ButtonContext) {
        switch context {
        case .floatingActionButton:
            shared.play(.buttonTapHeavy, context: AudioContext(intensity: 0.8, urgency: 0, celebration: 0, delay: 0, hapticPattern: .heavyTap, visualEffect: .premiumGlow))
        }
    }
    
    // MARK: - Context Enums
    
    enum TaskContext {
        case taskCompletion
    }
    
    enum ErrorContext {
        case systemError
    }
    
    enum SuccessContext {
        case taskRefreshComplete
    }
    
    enum FilterContext {
        case taskFilterChange
    }
    
    enum RefreshContext {
        case taskRefreshStart
    }
    
    enum TaskInteractionContext {
        case taskButtonPress
    }
    
    enum ButtonContext {
        case floatingActionButton
    }
    
    enum ButtonTapStyle {
        case light, medium, heavy
    }
}

// MARK: - 🎭 SwiftUI Integration Helpers

struct PremiumAudioButton: View {
    let title: String
    let action: () -> Void
    let style: PremiumAudioHapticSystem.ButtonTapStyle
    
    init(_ title: String, style: PremiumAudioHapticSystem.ButtonTapStyle = .medium, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            PremiumAudioHapticSystem.playButtonTap(style: style)
            action()
        }) {
            Text(title)
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
                )
        }
    }
}
