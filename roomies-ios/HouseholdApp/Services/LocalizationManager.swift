import Foundation

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: Language = .english {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "selectedLanguage")
        }
    }
    
    enum Language: String, CaseIterable {
        case english = "en"
        case german = "de"
        
        var displayName: String {
            switch self {
            case .english: return "English"
            case .german: return "Deutsch"
            }
        }
        
        var flag: String {
            switch self {
            case .english: return "🇺🇸"
            case .german: return "🇩🇪"
            }
        }
    }
    
    private var localizations: [String: [String: String]] = [:]
    
    private init() {
        loadSavedLanguage()
        setupLocalizations()
    }
    
    private func loadSavedLanguage() {
        if let savedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage"),
           let language = Language(rawValue: savedLanguage) {
            currentLanguage = language
        }
    }
    
    private func setupLocalizations() {
        // English localizations
        localizations["en"] = [
            // App Name
            "app.name": "Roomies",
            "app.tagline": "Making household management fun and animated",
            
            // Onboarding
            "onboarding.welcome.title": "Welcome to Roomies",
            "onboarding.welcome.description": "Organize your household playfully and efficiently with your family or roommates",
            "onboarding.tasks.title": "Tasks & Rewards",
            "onboarding.tasks.description": "Earn points for completed tasks and redeem them for custom rewards",
            "onboarding.challenges.title": "Challenges & Competitions",
            "onboarding.challenges.description": "Participate in challenges and climb the leaderboards",
            "onboarding.get_started": "Get Started!",
            "onboarding.skip": "Skip",
            "onboarding.next": "Next",
            
            // Authentication
            "auth.sign_in": "Sign In",
            "auth.sign_up": "Sign Up",
            "auth.email": "Email",
            "auth.password": "Password",
            "auth.name": "Name",
            "auth.confirm_password": "Confirm Password",
            "auth.forgot_password": "Forgot Password?",
            "auth.no_account": "Don't have an account?",
            "auth.have_account": "Already have an account?",
            
            // Errors
            "error.invalid_email": "Please enter a valid email address",
            "error.password_too_short": "Password must be at least 6 characters",
            "error.user_already_exists": "A user with this email already exists",
            "error.database_error": "Database error occurred",
            "error.user_not_found": "User not found",
            "error.invalid_password": "Invalid password",
            "error.login_failed": "Login failed",
            "error.registration_failed": "Registration failed",
            
            // Navigation
            "nav.dashboard": "Dashboard",
            "nav.tasks": "Tasks",
            "nav.challenges": "Challenges",
            "nav.leaderboard": "Leaderboard",
            "nav.profile": "Profile",
            "nav.store": "Store",
            
            // Dashboard
            "dashboard.hello": "Hello, %@!",
            "dashboard.overview": "Here's your daily overview",
            "dashboard.points": "Points",
            "dashboard.tasks_completed": "Completed Today",
            "dashboard.weekly_streak": "Weekly Streak",
            "dashboard.days": "days",
            "dashboard.upcoming_tasks": "Upcoming Tasks",
            "dashboard.active_challenges": "Active Challenges",
            "dashboard.recent_achievements": "Recent Achievements",
            "dashboard.all_tasks_done": "All tasks completed!",
            "dashboard.no_challenges": "No active challenges",
            "dashboard.show_all": "Show All",
            
            // Tasks
            "tasks.title": "Tasks",
            "tasks.all": "All",
            "tasks.pending": "Open",
            "tasks.completed": "Completed",
            "tasks.assigned": "Assigned to Me",
            "tasks.add_task": "Add Task",
            "tasks.no_tasks": "No tasks available",
            "tasks.create_first": "Add your first task and start organizing your household.",
            "tasks.complete": "Complete",
            "tasks.delete": "Delete",
            
            // Store/Rewards
            "store.title": "Reward Store",
            "store.available_rewards": "Available Rewards",
            "store.my_rewards": "My Rewards",
            "store.redeem": "Redeem",
            "store.redeemed": "Redeemed",
            "store.not_enough_points": "Not enough points",
            "store.redeem_success": "Reward redeemed successfully!",
            
            // Settings
            "settings.title": "Settings",
            "settings.language": "Language",
            "settings.notifications": "Notifications",
            "settings.account": "Account",
            "settings.sign_out": "Sign Out",
            
            // Common
            "common.save": "Save",
            "common.cancel": "Cancel",
            "common.delete": "Delete",
            "common.edit": "Edit",
            "common.done": "Done",
            "common.close": "Close",
            "common.yes": "Yes",
            "common.no": "No",
            
            // App Info
            "app.version": "Version",
            "app.ios_requirement": "iOS Requirement",
            "app.ios_17_plus": "iOS 17.0+",
            "app.about": "About the App",
            "app.rate": "Rate App",
            "app.feedback": "Send Feedback",
            
            // System Requirements
            "system.requirements": "System Requirements",
            "system.minimum_ios": "Minimum iOS Version",
            "system.compatible_devices": "Compatible Devices",
            "system.ios_17_required": "This app requires iOS 17.0 or later",
        ]
        
        // German localizations
        localizations["de"] = [
            // App Name
            "app.name": "Roomies",
            
            // Onboarding
            "onboarding.welcome.title": "Willkommen bei Roomies",
            "onboarding.welcome.description": "Organisiere deinen Haushalt spielerisch und effizient mit deiner Familie oder WG",
            "onboarding.tasks.title": "Aufgaben & Belohnungen",
            "onboarding.tasks.description": "Sammle Punkte für erledigte Aufgaben und löse sie für individuelle Belohnungen ein",
            "onboarding.challenges.title": "Challenges & Wettkämpfe",
            "onboarding.challenges.description": "Nimm an Herausforderungen teil und klettere in den Bestenlisten nach oben",
            "onboarding.get_started": "Los geht's!",
            "onboarding.skip": "Überspringen",
            "onboarding.next": "Weiter",
            
            // Biometric & App Lock
            "biometric.section_title": "Biometrische Authentifizierung",
            "biometric.app_locked": "App gesperrt",
            "biometric.unlock_prompt": "Verwenden Sie Face ID oder Touch ID, um die App zu entsperren",
            "biometric.unlock_button": "Entsperren",
            "biometric.app_lock_setting": "App-Sperre",
            "biometric.face_touch_id": "Face ID / Touch ID aktiviert",
            "biometric.auth_unavailable": "Biometrische Authentifizierung nicht verfügbar",
            
            // Calendar Settings
            "calendar.task_reminders": "Aufgaben-Erinnerungen",
            "calendar.deadline_notifications": "Deadline-Benachrichtigungen",
            "calendar.integration": "Kalender-Integration",
            "calendar.sync_enabled": "Kalender-Synchronisation",
            
            // Authentication
            "auth.sign_in": "Anmelden",
            "auth.sign_up": "Registrieren",
            "auth.email": "E-Mail",
            "auth.password": "Passwort",
            "auth.name": "Name",
            "auth.confirm_password": "Passwort bestätigen",
            "auth.forgot_password": "Passwort vergessen?",
            "auth.no_account": "Noch kein Konto?",
            "auth.have_account": "Bereits ein Konto?",
            
            // Errors
            "error.invalid_email": "Bitte geben Sie eine gültige E-Mail-Adresse ein",
            "error.password_too_short": "Das Passwort muss mindestens 6 Zeichen haben",
            "error.user_already_exists": "Ein Benutzer mit dieser E-Mail existiert bereits",
            "error.database_error": "Ein Datenbankfehler ist aufgetreten",
            "error.user_not_found": "Benutzer nicht gefunden",
            "error.invalid_password": "Ungültiges Passwort",
            "error.login_failed": "Anmeldung fehlgeschlagen",
            "error.registration_failed": "Registrierung fehlgeschlagen",
            
            // Navigation
            "nav.dashboard": "Dashboard",
            "nav.tasks": "Aufgaben",
            "nav.challenges": "Challenges",
            "nav.leaderboard": "Bestenliste",
            "nav.profile": "Profil",
            "nav.store": "Shop",
            
            // Dashboard
            "dashboard.hello": "Hallo, %@!",
            "dashboard.overview": "Hier ist deine heutige Übersicht",
            "dashboard.points": "Punkte",
            "dashboard.tasks_completed": "Heute erledigt",
            "dashboard.weekly_streak": "Wochenstreak",
            "dashboard.days": "Tage",
            "dashboard.upcoming_tasks": "Anstehende Aufgaben",
            "dashboard.active_challenges": "Aktive Challenges",
            "dashboard.recent_achievements": "Neue Erfolge",
            "dashboard.all_tasks_done": "Alle Aufgaben erledigt!",
            "dashboard.no_challenges": "Keine aktiven Challenges",
            "dashboard.show_all": "Alle anzeigen",
            
            // Tasks
            "tasks.title": "Aufgaben",
            "tasks.all": "Alle",
            "tasks.pending": "Offen",
            "tasks.completed": "Erledigt",
            "tasks.assigned": "Mir zugewiesen",
            "tasks.add_task": "Aufgabe hinzufügen",
            "tasks.no_tasks": "Keine Aufgaben vorhanden",
            "tasks.create_first": "Füge deine erste Aufgabe hinzu und beginne mit der Organisation deines Haushalts.",
            "tasks.complete": "Erledigt",
            "tasks.delete": "Löschen",
            
            // Store/Rewards
            "store.title": "Belohnungs-Shop",
            "store.available_rewards": "Verfügbare Belohnungen",
            "store.my_rewards": "Meine Belohnungen",
            "store.redeem": "Einlösen",
            "store.redeemed": "Eingelöst",
            "store.not_enough_points": "Nicht genügend Punkte",
            "store.redeem_success": "Belohnung erfolgreich eingelöst!",
            
            // Task Related
            "task.none": "Keine",
            "task.daily": "Täglich",
            "task.weekly": "Wöchentlich",
            "task.priority": "Priorität",
            "task.due_date_section": "Fälligkeit",
            "task.set_due_date": "Fälligkeitsdatum setzen",
            "task.due_on": "Fällig am",
            
            // Notifications
            "notification.task_due": "Aufgabe fällig",
            "notification.challenge_expiring": "Challenge läuft ab",
            "notification.weekly_leaderboard": "Wöchentliche Bestenliste",
            
            // Profile & Settings
            "profile.member_since": "Mitglied seit März 2024",
            "profile.performance_monitoring": "Performance-Überwachung",
            "profile.total_overview": "Gesamtübersicht",
            "profile.kitchen_category": "Küche",
            "profile.delete_all_data": "Alle Daten löschen",
            "profile.about_app": "Über die App",
            "profile.privacy_policy": "Datenschutzerklärung",
            "profile.data_transfer": "Datenübertragung",
            "profile.gdpr_compliance": "DSGVO-Konformität",
            
            // Household Management
            "household.close_button": "Schließen",
            "household.delete_household": "Haushalt löschen",
            "household.delete_confirmation": "Diese Aktion kann nicht rückgängig gemacht werden. Alle Aufgaben und Challenges werden gelöscht.",
            "household.choose_avatar_color": "Wähle eine Avatar-Farbe",
            "household.invalid_invite_code": "Ungültiger Einladungscode. Bitte überprüfe den Code und versuche es erneut.",
            
            // Challenges
            "challenges.available": "Verfügbar",
            "challenges.kitchen_master": "Küchenmeister",
            "challenges.cleanup_champion": "Aufräum-Champion",
            "challenges.days_remaining": "d übrig",
            "challenges.starts_immediately": "Die Challenge startet sofort nach der Erstellung und läuft",
            "challenges.days_duration": "Tage.",
            
            // Leaderboard
            "leaderboard.no_activity": "Noch keine Aktivität",
            
            // QR Code & Invites
            "qr.scan_to_join": "Andere können diesen QR-Code scannen, um deinem Haushalt beizutreten",
            "invite.download_app": "Die Person lädt die App herunter",
            
            // Dashboard
            "dashboard.todays_overview": "Hier ist deine heutige Übersicht",
            
            // Badges
            "badge.cleanup_expert": "Aufräumer",
            
            // Settings
            "settings.title": "Einstellungen",
            "settings.language": "Sprache",
            "settings.notifications": "Benachrichtigungen",
            "settings.account": "Konto",
            "settings.sign_out": "Abmelden",
            
            // Common
            "common.save": "Speichern",
            "common.cancel": "Abbrechen",
            "common.delete": "Löschen",
            "common.edit": "Bearbeiten",
            "common.done": "Fertig",
            "common.close": "Schließen",
            "common.days": "Tage",
            "common.yes": "Ja",
            "common.no": "Nein",
            
            // App Info
            "app.version": "Version",
            "app.ios_requirement": "iOS Anforderung",
            "app.ios_17_plus": "iOS 17.0+",
            "app.about": "Über die App",
            "app.rate": "App bewerten",
            "app.feedback": "Feedback senden",
            
            // System Requirements
            "system.requirements": "Systemanforderungen",
            "system.minimum_ios": "Mindest-iOS-Version",
            "system.compatible_devices": "Kompatible Geräte",
            "system.ios_17_required": "Diese App benötigt iOS 17.0 oder neuer",
        ]
    }
    
    func localizedString(_ key: String) -> String {
        return localizations[currentLanguage.rawValue]?[key] ?? key
    }
    
    func localizedString(_ key: String, _ args: CVarArg...) -> String {
        let format = localizedString(key)
        return String(format: format, arguments: args)
    }
}
