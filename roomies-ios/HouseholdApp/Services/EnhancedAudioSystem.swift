import Foundation
import AVFoundation
import UIKit

// MARK: - Enhanced Audio System
class EnhancedAudioSystem: ObservableObject {
    static let shared = EnhancedAudioSystem()
    
    // Audio players for different sound categories
    private var audioPlayers: [SoundCategory: AVAudioPlayer] = [:]
    private var backgroundMusicPlayer: AVAudioPlayer?
    
    // Audio settings
    @Published var masterVolume: Float = 1.0
    @Published var musicVolume: Float = 0.3
    @Published var effectsVolume: Float = 0.7
    @Published var isAudioEnabled = true
    @Published var currentTheme: AudioTheme = .default
    
    // Sound queue for sequential playback
    private var soundQueue: [QueuedSound] = []
    private var isPlayingQueue = false
    
    // MARK: - Sound Categories
    enum SoundCategory: String, CaseIterable {
        // Achievement sounds
        case levelUp = "level_up"
        case achievementUnlock = "achievement_unlock"
        case badgeEarned = "badge_earned"
        case milestoneReached = "milestone"
        
        // Task sounds
        case taskComplete = "task_complete"
        case taskCreate = "task_create"
        case taskDelete = "task_delete"
        case taskEdit = "task_edit"
        
        // Challenge sounds
        case challengeStart = "challenge_start"
        case challengeComplete = "challenge_complete"
        case challengeProgress = "challenge_progress"
        
        // Reward sounds
        case rewardRedeem = "reward_redeem"
        case pointsEarned = "points_earned"
        case coinCollect = "coin_collect"
        
        // UI sounds
        case buttonTap = "button_tap"
        case tabSwitch = "tab_switch"
        case pullRefresh = "pull_refresh"
        case swipeAction = "swipe_action"
        case toggleSwitch = "toggle_switch"
        
        // Notification sounds
        case notificationGentle = "notification_gentle"
        case notificationUrgent = "notification_urgent"
        case reminder = "reminder"
        
        // Victory sounds
        case victorySmall = "victory_small"
        case victoryMedium = "victory_medium"
        case victoryLarge = "victory_large"
        case epicWin = "epic_win"
        
        // Error/Warning sounds
        case error = "error"
        case warning = "warning"
        case denied = "denied"
        
        var systemSoundID: SystemSoundID {
            switch self {
            case .levelUp: return 1025
            case .achievementUnlock: return 1013
            case .badgeEarned: return 1023
            case .milestoneReached: return 1027
            case .taskComplete: return 1057
            case .taskCreate: return 1104
            case .taskDelete: return 1053
            case .taskEdit: return 1104
            case .challengeStart: return 1016
            case .challengeComplete: return 1025
            case .challengeProgress: return 1106
            case .rewardRedeem: return 1023
            case .pointsEarned: return 1057
            case .coinCollect: return 1106
            case .buttonTap: return 1104
            case .tabSwitch: return 1103
            case .pullRefresh: return 1024
            case .swipeAction: return 1052
            case .toggleSwitch: return 1103
            case .notificationGentle: return 1002
            case .notificationUrgent: return 1005
            case .reminder: return 1013
            case .victorySmall: return 1022
            case .victoryMedium: return 1025
            case .victoryLarge: return 1027
            case .epicWin: return 1023
            case .error: return 1053
            case .warning: return 1006
            case .denied: return 1053
            }
        }
    }
    
    // MARK: - Audio Themes
    enum AudioTheme: String, CaseIterable {
        case `default` = "Default"
        case playful = "Playful"
        case minimal = "Minimal"
        case retro = "Retro"
        case zen = "Zen"
        
        var backgroundMusic: String? {
            switch self {
            case .default: return nil
            case .playful: return "playful_background"
            case .minimal: return nil
            case .retro: return "retro_background"
            case .zen: return "zen_background"
            }
        }
        
        func modifySound(_ category: SoundCategory) -> (pitch: Float, rate: Float, reverb: Float) {
            switch self {
            case .default:
                return (1.0, 1.0, 0.0)
            case .playful:
                return (1.2, 1.1, 0.1)
            case .minimal:
                return (0.9, 1.0, 0.0)
            case .retro:
                return (0.8, 0.9, 0.2)
            case .zen:
                return (1.0, 0.8, 0.3)
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        setupAudioSession()
        loadUserPreferences()
        prepareAudioPlayers()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func loadUserPreferences() {
        isAudioEnabled = UserDefaults.standard.bool(forKey: "enhancedAudioEnabled")
        masterVolume = UserDefaults.standard.float(forKey: "masterVolume")
        if masterVolume == 0 { masterVolume = 1.0 }
        
        musicVolume = UserDefaults.standard.float(forKey: "musicVolume")
        if musicVolume == 0 { musicVolume = 0.3 }
        
        effectsVolume = UserDefaults.standard.float(forKey: "effectsVolume")
        if effectsVolume == 0 { effectsVolume = 0.7 }
        
        if let themeString = UserDefaults.standard.string(forKey: "audioTheme"),
           let theme = AudioTheme(rawValue: themeString) {
            currentTheme = theme
        }
    }
    
    private func prepareAudioPlayers() {
        // Pre-load common sounds for better performance
        let commonSounds: [SoundCategory] = [
            .buttonTap, .taskComplete, .pointsEarned, .tabSwitch
        ]
        
        for sound in commonSounds {
            _ = preparePlayer(for: sound)
        }
    }
    
    private func preparePlayer(for category: SoundCategory) -> AVAudioPlayer? {
        // In production, load actual audio files
        // For now, we'll use system sounds
        return nil
    }
    
    // MARK: - Public Interface
    
    // Play a single sound with optional customization
    func play(_ category: SoundCategory, 
              volume: Float? = nil,
              pitch: Float? = nil,
              delay: TimeInterval = 0) {
        
        guard isAudioEnabled else { return }
        
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.playSound(category, volume: volume, pitch: pitch)
            }
        } else {
            playSound(category, volume: volume, pitch: pitch)
        }
    }
    
    // Play a sequence of sounds
    func playSequence(_ sounds: [(category: SoundCategory, delay: TimeInterval)]) {
        guard isAudioEnabled else { return }
        
        for (index, sound) in sounds.enumerated() {
            let totalDelay = sounds[0..<index].reduce(0) { $0 + $1.delay } + sound.delay
            
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
                self.play(sound.category)
            }
        }
    }
    
    // Play victory fanfare based on achievement level
    func playVictoryFanfare(level: VictoryLevel) {
        switch level {
        case .small:
            playSequence([
                (.victorySmall, 0),
                (.coinCollect, 0.2)
            ])
            
        case .medium:
            playSequence([
                (.victoryMedium, 0),
                (.pointsEarned, 0.3),
                (.coinCollect, 0.5)
            ])
            
        case .large:
            playSequence([
                (.victoryLarge, 0),
                (.achievementUnlock, 0.4),
                (.pointsEarned, 0.6),
                (.coinCollect, 0.8)
            ])
            
        case .epic:
            playSequence([
                (.epicWin, 0),
                (.achievementUnlock, 0.3),
                (.levelUp, 0.6),
                (.coinCollect, 0.9),
                (.victoryLarge, 1.2)
            ])
        }
        
        // Trigger haptic feedback
        triggerVictoryHaptics(level: level)
    }
    
    // Play level up celebration
    func playLevelUpCelebration(newLevel: Int) {
        playSequence([
            (.levelUp, 0),
            (.achievementUnlock, 0.3),
            (.pointsEarned, 0.5)
        ])
        
        // Special effects for milestone levels
        if newLevel % 10 == 0 {
            play(.milestoneReached, delay: 0.8)
        }
    }
    
    // Play task completion with point value feedback
    func playTaskCompletion(points: Int) {
        play(.taskComplete)
        
        // Add extra sounds based on point value
        if points >= 100 {
            play(.coinCollect, delay: 0.3)
            play(.pointsEarned, delay: 0.5)
        } else if points >= 50 {
            play(.coinCollect, delay: 0.3)
        }
    }
    
    // MARK: - Background Music
    
    func startBackgroundMusic() {
        guard currentTheme.backgroundMusic != nil else { return }
        
        // In production, load and play the music file
        // For now, we'll just set the flag
        backgroundMusicPlayer?.volume = musicVolume * masterVolume
        backgroundMusicPlayer?.numberOfLoops = -1
        backgroundMusicPlayer?.play()
    }
    
    func stopBackgroundMusic() {
        backgroundMusicPlayer?.stop()
    }
    
    func fadeBackgroundMusic(to volume: Float, duration: TimeInterval) {
        guard let player = backgroundMusicPlayer else { return }
        
        let steps = 20
        let stepDuration = duration / Double(steps)
        let volumeStep = (volume - player.volume) / Float(steps)
        
        for i in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                player.volume += volumeStep
            }
        }
    }
    
    // MARK: - Theme Management
    
    func setTheme(_ theme: AudioTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "audioTheme")
        
        // Restart background music if needed
        stopBackgroundMusic()
        if theme.backgroundMusic != nil {
            startBackgroundMusic()
        }
    }
    
    // MARK: - Private Methods
    
    private func playSound(_ category: SoundCategory, volume: Float? = nil, pitch: Float? = nil) {
        // Use system sound for now
        AudioServicesPlaySystemSound(category.systemSoundID)
        
        // In production, use AVAudioPlayer with pitch and volume control
        if let player = audioPlayers[category] {
            let themeModifiers = currentTheme.modifySound(category)
            player.volume = (volume ?? effectsVolume) * masterVolume
            player.rate = themeModifiers.rate
            player.play()
        }
    }
    
    private func triggerVictoryHaptics(level: VictoryLevel) {
        switch level {
        case .small:
            let feedback = UIImpactFeedbackGenerator(style: .light)
            feedback.impactOccurred()
            
        case .medium:
            let feedback = UIImpactFeedbackGenerator(style: .medium)
            feedback.impactOccurred()
            
        case .large:
            let feedback = UIImpactFeedbackGenerator(style: .heavy)
            feedback.impactOccurred()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                feedback.impactOccurred()
            }
            
        case .epic:
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
            
            let heavyFeedback = UIImpactFeedbackGenerator(style: .heavy)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                heavyFeedback.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                heavyFeedback.impactOccurred()
            }
        }
    }
    
    // MARK: - Volume Control
    
    func setMasterVolume(_ volume: Float) {
        masterVolume = max(0, min(1, volume))
        UserDefaults.standard.set(masterVolume, forKey: "masterVolume")
    }
    
    func setMusicVolume(_ volume: Float) {
        musicVolume = max(0, min(1, volume))
        UserDefaults.standard.set(musicVolume, forKey: "musicVolume")
        backgroundMusicPlayer?.volume = musicVolume * masterVolume
    }
    
    func setEffectsVolume(_ volume: Float) {
        effectsVolume = max(0, min(1, volume))
        UserDefaults.standard.set(effectsVolume, forKey: "effectsVolume")
    }
    
    // MARK: - Supporting Types
    
    enum VictoryLevel {
        case small  // Single task completion
        case medium // Multiple tasks or small achievement
        case large  // Challenge completion or level up
        case epic   // Major milestone or rare achievement
    }
    
    private struct QueuedSound {
        let category: SoundCategory
        let delay: TimeInterval
        let volume: Float?
        let pitch: Float?
    }
}

// MARK: - SwiftUI Integration
extension EnhancedAudioSystem {
    static func playButton() {
        shared.play(.buttonTap)
    }
    
    static func playSuccess() {
        shared.play(.taskComplete)
    }
    
    static func playError() {
        shared.play(.error)
    }
    
    static func playToggle() {
        shared.play(.toggleSwitch)
    }
    
    static func playSwipe() {
        shared.play(.swipeAction)
    }
}
