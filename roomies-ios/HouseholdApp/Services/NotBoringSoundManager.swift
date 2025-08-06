import Foundation
import AVFoundation
import UIKit

class NotBoringSoundManager: ObservableObject {
    static let shared = NotBoringSoundManager()
    
    private var audioPlayers: [String: AVAudioPlayer] = [:]
    private var soundEnabled = true
    private var hapticEnabled = true
    
    // ✅ ENHANCED: Additional "Not Boring" sound types
    enum NotBoringSoundType {
        case taskComplete
        case pointsEarned
        case levelUp
        case challengeUnlocked
        case streakAchieved
        case leaderboardClimb
        case tabSwitch
        case floatingButtonTap
        case cardFlip
        case confettiPop
        case achievementUnlock
        case dailyGoalComplete
        case buttonTap
        case error
        case success
        case profileEdit
        case settingsChange
    }
    
    private init() {
        setupAudioSession()
        loadSounds()
        preloadSounds()
        loadUserPreferences() // Load user preferences on init
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func loadSounds() {
        // In a real app, you would load actual sound files
        // For now, we'll use system sounds with haptic feedback
    }
    
    // MARK: - Public Interface
    
    // ✅ ENHANCED: Comprehensive sound playing with contextual feedback
    func playSound(_ type: NotBoringSoundType) {
        switch type {
        case .taskComplete:
            playSystemSound(.complete)
            triggerHaptic(.success)
            addVisualFeedback(.checkmark)
            
        case .pointsEarned:
            playSystemSound(.points)
            triggerHaptic(.light)
            addVisualFeedback(.sparkle)
            
        case .levelUp:
            playSystemSound(.levelUp)
            triggerHaptic(.heavy)
            addVisualFeedback(.celebration)
            
            // Double haptic for extra emphasis
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.triggerHaptic(.heavy)
            }
            
        case .challengeUnlocked:
            playSystemSound(.unlock)
            triggerHaptic(.medium)
            addVisualFeedback(.unlock)
            
        case .streakAchieved:
            playSystemSound(.streak)
            triggerHaptic(.success)
            addVisualFeedback(.fire)
            
        case .leaderboardClimb:
            playSystemSound(.climb)
            triggerHaptic(.medium)
            addVisualFeedback(.trophy)
            
        case .tabSwitch:
            triggerHaptic(.selection)
            
        case .floatingButtonTap:
            triggerHaptic(.medium)
            addVisualFeedback(.ripple)
            
        case .cardFlip:
            playSystemSound(.flip)
            triggerHaptic(.light)
            
        case .confettiPop:
            playSystemSound(.pop)
            triggerHaptic(.light)
            addVisualFeedback(.confetti)
            
        case .achievementUnlock:
            playSystemSound(.achievement)
            triggerHaptic(.success)
            addVisualFeedback(.star)
            
        case .dailyGoalComplete:
            playSystemSound(.goalComplete)
            triggerHaptic(.heavy)
            addVisualFeedback(.goal)
            
        case .buttonTap:
            triggerHaptic(.light)
            
        case .error:
            playSystemSound(.error)
            triggerHaptic(.error)
            
        case .success:
            playSystemSound(.success)
            triggerHaptic(.success)
            addVisualFeedback(.checkmark)
            
        case .profileEdit:
            playSystemSound(.edit)
            triggerHaptic(.light)
            
        case .settingsChange:
            playSystemSound(.setting)
            triggerHaptic(.selection)
        }
    }
    
    // ✅ ENHANCED: Preload sounds for better performance
    func preloadSounds() {
        // Preload common sounds to avoid delays
        let commonSounds: [SystemSound] = [.complete, .points, .levelUp, .error, .success]
        for sound in commonSounds {
            _ = sound.soundID // This preloads the system sound
        }
    }
    
    // ✅ ENHANCED: Visual feedback integration
    private func addVisualFeedback(_ type: VisualFeedbackType) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("NotBoringVisualFeedback"),
                object: nil,
                userInfo: ["type": type]
            )
        }
    }
    
    private enum VisualFeedbackType {
        case checkmark, sparkle, celebration, unlock, fire, trophy, ripple, confetti, star, goal
    }
    
    // MARK: - Private Methods
    
    private enum SystemSound {
        case complete
        case points
        case levelUp
        case unlock
        case streak
        case climb
        case flip
        case pop
        case achievement
        case goalComplete
        case edit
        case setting
        case error
        case success
        
        var soundID: SystemSoundID {
            switch self {
            case .complete: return 1057 // SMS Received 4
            case .points: return 1106 // Camera shutter
            case .levelUp: return 1023 // SMS Received 1
            case .unlock: return 1013 // New Mail
            case .streak: return 1025 // SMS Received 3
            case .climb: return 1027 // SMS Received 5
            case .flip: return 1052 // Tweet Sent
            case .pop: return 1057 // SMS Received 4
            case .achievement: return 1016 // Camera shutter
            case .goalComplete: return 1005 // New Mail
            case .edit: return 1104 // Camera shutter
            case .setting: return 1103 // Camera shutter
            case .error: return 1053 // Tweet Sent
            case .success: return 1016 // Camera shutter
            }
        }
    }
    
    private func playSystemSound(_ sound: SystemSound) {
        guard soundEnabled else { return }
        AudioServicesPlaySystemSound(sound.soundID)
    }
    
    private func triggerHaptic(_ type: HapticType) {
        guard hapticEnabled else { return }
        
        switch type {
        case .light:
            let feedback = UIImpactFeedbackGenerator(style: .light)
            feedback.impactOccurred()
        case .medium:
            let feedback = UIImpactFeedbackGenerator(style: .medium)
            feedback.impactOccurred()
        case .heavy:
            let feedback = UIImpactFeedbackGenerator(style: .heavy)
            feedback.impactOccurred()
        case .selection:
            let feedback = UISelectionFeedbackGenerator()
            feedback.selectionChanged()
        case .success:
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
        case .error:
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.error)
        case .warning:
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.warning)
        }
    }
    
    private enum HapticType {
        case light, medium, heavy, selection, success, error, warning
    }
    
    // MARK: - Settings Management
    
    func setSoundEnabled(_ enabled: Bool) {
        soundEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "notBoringSoundEnabled")
    }
    
    func setHapticEnabled(_ enabled: Bool) {
        hapticEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "notBoringHapticEnabled")
    }
    
    var isSoundEnabled: Bool {
        return soundEnabled
    }
    
    var isHapticEnabled: Bool {
        return hapticEnabled
    }
    
    // ✅ ENHANCED: Load user preferences
    private func loadUserPreferences() {
        soundEnabled = UserDefaults.standard.bool(forKey: "notBoringSoundEnabled")
        hapticEnabled = UserDefaults.standard.bool(forKey: "notBoringHapticEnabled")
    }
    
    // ✅ ENHANCED: Contextual sound sequences for complex actions
    func playSequence(_ sequence: SoundSequence) {
        switch sequence {
        case .taskCompleteWithPoints(let points):
            playSound(.taskComplete)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.playSound(.pointsEarned)
            }
            if points >= 100 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self.playSound(.levelUp)
                }
            }
            
        case .challengeCompleteWithReward:
            playSound(.challengeUnlocked)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.playSound(.pointsEarned)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.playSound(.achievementUnlock)
            }
            
        case .dailyGoalSequence:
            playSound(.taskComplete)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.playSound(.taskComplete)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.playSound(.dailyGoalComplete)
            }
            
        case .leaderboardClimbSequence(let positions):
            for (index, _) in positions.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2) {
                    self.playSound(.leaderboardClimb)
                }
            }
        }
    }
    
    enum SoundSequence {
        case taskCompleteWithPoints(Int)
        case challengeCompleteWithReward
        case dailyGoalSequence
        case leaderboardClimbSequence([Int])
    }
}

// ✅ ENHANCED: Extension for easy integration
extension NotBoringSoundManager {
    static func play(_ type: NotBoringSoundType) {
        shared.playSound(type)
    }
    
    static func playSequence(_ sequence: SoundSequence) {
        shared.playSequence(sequence)
    }
}