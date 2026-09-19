import Testing
@testable import Common

struct PasswordStrengthValidatorTests {
    @Test
    func emptyPasswordFailsAllRules() {
        let result = PasswordStrengthValidator.evaluate("")
        #expect(result.isStrong == false)
        #expect(result.failedRules == PasswordRule.allCases)
    }

    @Test
    func reportsOnlyMissingRules() {
        let result = PasswordStrengthValidator.evaluate("abcdefgh")
        #expect(result.isStrong == false)
        #expect(result.failedRules.contains(.uppercase))
        #expect(result.failedRules.contains(.digit))
        #expect(result.failedRules.contains(.specialCharacter))
        #expect(!result.failedRules.contains(.minLength))
        #expect(!result.failedRules.contains(.lowercase))
    }

    @Test
    func acceptsStrongPassword() {
        let result = PasswordStrengthValidator.evaluate("Abcdef1!")
        #expect(result.isStrong)
        #expect(result.failedRules.isEmpty)
    }
}
