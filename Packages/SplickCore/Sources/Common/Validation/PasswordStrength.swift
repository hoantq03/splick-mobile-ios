import Foundation

public enum PasswordRule: String, CaseIterable, Sendable {
    case minLength
    case uppercase
    case lowercase
    case digit
    case specialCharacter

    public var guideText: String {
        switch self {
        case .minLength:
            return "At least \(AppConstants.Validation.minPasswordLength) characters"
        case .uppercase:
            return "One uppercase letter (A–Z)"
        case .lowercase:
            return "One lowercase letter (a–z)"
        case .digit:
            return "One number (0–9)"
        case .specialCharacter:
            return "One special character (!@#$%…)"
        }
    }
}

public struct PasswordStrengthResult: Equatable, Sendable {
    public let isStrong: Bool
    public let failedRules: [PasswordRule]

    public static let empty = PasswordStrengthResult(isStrong: false, failedRules: PasswordRule.allCases)

    public var guideTitle: String {
        "Use a strong password"
    }

    public var guideItems: [(rule: PasswordRule, met: Bool)] {
        PasswordRule.allCases.map { rule in
            (rule, !failedRules.contains(rule))
        }
    }
}

public enum PasswordStrengthValidator {
    private static let specialCharacterPattern = #"[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>/?`~]"#

    public static func evaluate(_ password: String) -> PasswordStrengthResult {
        guard !password.isEmpty else { return .empty }

        var failed: [PasswordRule] = []

        if password.count < AppConstants.Validation.minPasswordLength
            || password.count > AppConstants.Validation.maxPasswordLength {
            failed.append(.minLength)
        }
        if password.range(of: "[A-Z]", options: .regularExpression) == nil {
            failed.append(.uppercase)
        }
        if password.range(of: "[a-z]", options: .regularExpression) == nil {
            failed.append(.lowercase)
        }
        if password.range(of: "[0-9]", options: .regularExpression) == nil {
            failed.append(.digit)
        }
        if password.range(of: specialCharacterPattern, options: .regularExpression) == nil {
            failed.append(.specialCharacter)
        }

        return PasswordStrengthResult(isStrong: failed.isEmpty, failedRules: failed)
    }
}
