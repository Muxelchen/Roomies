import Foundation

/// Comprehensive input validation manager
class ValidationManager {
    static let shared = ValidationManager()
    
    private init() {}
    
    // MARK: - Email Validation
    func isValidEmail(_ email: String) -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for empty string
        guard !trimmedEmail.isEmpty else { return false }
        
        // More comprehensive email regex
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        // Additional checks
        let hasAtSymbol = trimmedEmail.contains("@")
        let hasDot = trimmedEmail.contains(".")
        let noConsecutiveDots = !trimmedEmail.contains("..")
        let doesntStartWithDot = !trimmedEmail.hasPrefix(".")
        let doesntEndWithDot = !trimmedEmail.hasSuffix(".")
        
        return emailPredicate.evaluate(with: trimmedEmail) &&
               hasAtSymbol && hasDot && noConsecutiveDots &&
               doesntStartWithDot && doesntEndWithDot
    }
    
    // MARK: - Password Validation
    struct PasswordValidationResult {
        let isValid: Bool
        let errors: [String]
        let strength: PasswordStrength
    }
    
    enum PasswordStrength: String, CaseIterable {
        case weak = "Weak"
        case fair = "Fair"
        case good = "Good"
        case strong = "Strong"
        case veryStrong = "Very Strong"
        
        var color: String {
            switch self {
            case .weak: return "red"
            case .fair: return "orange"
            case .good: return "yellow"
            case .strong: return "green"
            case .veryStrong: return "blue"
            }
        }
    }
    
    func validatePassword(_ password: String) -> PasswordValidationResult {
        var errors: [String] = []
        var strengthScore = 0
        
        // Minimum length
        if password.count < 8 {
            errors.append("Password must be at least 8 characters")
        } else if password.count >= 12 {
            strengthScore += 2
        } else {
            strengthScore += 1
        }
        
        // Uppercase check
        let hasUppercase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        if !hasUppercase {
            errors.append("Password must contain at least one uppercase letter")
        } else {
            strengthScore += 1
        }
        
        // Lowercase check
        let hasLowercase = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        if !hasLowercase {
            errors.append("Password must contain at least one lowercase letter")
        } else {
            strengthScore += 1
        }
        
        // Number check
        let hasNumber = password.rangeOfCharacter(from: .decimalDigits) != nil
        if !hasNumber {
            errors.append("Password must contain at least one number")
        } else {
            strengthScore += 1
        }
        
        // Special character check
        let specialCharacters = CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")
        let hasSpecialChar = password.rangeOfCharacter(from: specialCharacters) != nil
        if hasSpecialChar {
            strengthScore += 2
        }
        
        // Common password check
        if isCommonPassword(password) {
            errors.append("This password is too common")
            strengthScore = max(0, strengthScore - 3)
        }
        
        // Determine strength
        let strength: PasswordStrength
        switch strengthScore {
        case 0...2: strength = .weak
        case 3...4: strength = .fair
        case 5...6: strength = .good
        case 7...8: strength = .strong
        default: strength = .veryStrong
        }
        
        let isValid = errors.isEmpty && password.count >= 8
        
        return PasswordValidationResult(isValid: isValid, errors: errors, strength: strength)
    }
    
    private func isCommonPassword(_ password: String) -> Bool {
        let commonPasswords = [
            "password", "123456", "password123", "admin", "letmein",
            "qwerty", "abc123", "monkey", "dragon", "master",
            "password1", "123456789", "qwertyuiop", "1234567890"
        ]
        return commonPasswords.contains(password.lowercased())
    }
    
    // MARK: - Name Validation
    func isValidName(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check length
        guard trimmedName.count >= 2 && trimmedName.count <= 50 else { return false }
        
        // Check for invalid characters (allow letters, spaces, hyphens, apostrophes)
        let nameRegex = "^[a-zA-Z\\s'-]+$"
        let namePredicate = NSPredicate(format: "SELF MATCHES %@", nameRegex)
        
        return namePredicate.evaluate(with: trimmedName)
    }
    
    // MARK: - Task Validation
    func isValidTaskTitle(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 3 && trimmed.count <= 100
    }
    
    func isValidTaskDescription(_ description: String) -> Bool {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count <= 500
    }
    
    func isValidTaskPoints(_ points: Int) -> Bool {
        return points >= 0 && points <= 1000
    }
    
    // MARK: - Household Validation
    func isValidHouseholdName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 3 && trimmed.count <= 50
    }
    
    func isValidInviteCode(_ code: String) -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check length
        guard trimmed.count >= 6 && trimmed.count <= 10 else { return false }
        
        // Allow only alphanumeric characters
        let codeRegex = "^[A-Z0-9]+$"
        let codePredicate = NSPredicate(format: "SELF MATCHES %@", codeRegex)
        
        return codePredicate.evaluate(with: trimmed.uppercased())
    }
    
    // MARK: - Date Validation
    func isValidFutureDate(_ date: Date) -> Bool {
        return date > Date()
    }
    
    func isValidDateRange(start: Date, end: Date) -> Bool {
        return start < end
    }
    
    // MARK: - Sanitization
    func sanitizeInput(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove any potential HTML/Script tags
        let htmlRegex = try? NSRegularExpression(pattern: "<[^>]+>", options: .caseInsensitive)
        let range = NSRange(location: 0, length: trimmed.utf16.count)
        let sanitized = htmlRegex?.stringByReplacingMatches(in: trimmed, options: [], range: range, withTemplate: "") ?? trimmed
        
        // Remove multiple spaces
        let components = sanitized.components(separatedBy: .whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.joined(separator: " ")
    }
    
    // MARK: - Phone Number Validation
    func isValidPhoneNumber(_ phone: String) -> Bool {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common formatting characters
        let digitsOnly = trimmed.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Check for valid phone number length (10-15 digits internationally)
        return digitsOnly.count >= 10 && digitsOnly.count <= 15
    }
    
    // MARK: - URL Validation
    func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme != nil && url.host != nil
    }
    
    // MARK: - Credit Card Validation (for future store features)
    func isValidCreditCardNumber(_ number: String) -> Bool {
        let digitsOnly = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Check length
        guard digitsOnly.count >= 13 && digitsOnly.count <= 19 else { return false }
        
        // Luhn algorithm
        return luhnCheck(digitsOnly)
    }
    
    private func luhnCheck(_ number: String) -> Bool {
        let reversedDigits = number.reversed().compactMap { Int(String($0)) }
        var sum = 0
        
        for (index, digit) in reversedDigits.enumerated() {
            if index % 2 == 1 {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }
        
        return sum % 10 == 0
    }
}

// MARK: - Validation Extensions
extension String {
    var isValidEmail: Bool {
        return ValidationManager.shared.isValidEmail(self)
    }
    
    var isValidName: Bool {
        return ValidationManager.shared.isValidName(self)
    }
    
    var sanitized: String {
        return ValidationManager.shared.sanitizeInput(self)
    }
    
    var isValidURL: Bool {
        return ValidationManager.shared.isValidURL(self)
    }
    
    var isValidPhoneNumber: Bool {
        return ValidationManager.shared.isValidPhoneNumber(self)
    }
}
