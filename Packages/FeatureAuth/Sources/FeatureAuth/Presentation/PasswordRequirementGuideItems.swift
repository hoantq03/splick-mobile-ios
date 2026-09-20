import Common
import DesignSystem
import Localization

@MainActor
func passwordRequirementGuideItems(
    for password: String,
    languageService: LanguageService
) -> [PasswordRequirementGuideItem] {
    PasswordStrengthValidator.evaluate(password).guideItems.map { item in
        PasswordRequirementGuideItem(
            label: languageService.passwordRuleText(item.rule),
            met: item.met
        )
    }
}
