import SwiftUI
import Localization

public struct LegalLinksFooter: View {
    @EnvironmentObject private var languageService: LanguageService

    @Binding private var hasAcceptedTerms: Bool
    private let showsConsentCheckbox: Bool
    private let onOpenTerms: () -> Void
    private let onOpenPrivacy: () -> Void

    public init(
        hasAcceptedTerms: Binding<Bool> = .constant(true),
        showsConsentCheckbox: Bool = false,
        onOpenTerms: @escaping () -> Void,
        onOpenPrivacy: @escaping () -> Void
    ) {
        _hasAcceptedTerms = hasAcceptedTerms
        self.showsConsentCheckbox = showsConsentCheckbox
        self.onOpenTerms = onOpenTerms
        self.onOpenPrivacy = onOpenPrivacy
    }

    public var body: some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            if showsConsentCheckbox {
                Button {
                    hasAcceptedTerms.toggle()
                } label: {
                    HStack(alignment: .top, spacing: SplickTheme.Spacing.sm) {
                        Image(systemName: hasAcceptedTerms ? "checkmark.square.fill" : "square")
                            .font(.system(size: 20))
                            .foregroundStyle(
                                hasAcceptedTerms
                                    ? SplickTheme.Colors.primaryGradientStart
                                    : SplickTheme.Colors.textSecondary
                            )
                        consentText
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
            } else {
                consentText
            }
        }
        .padding(.top, SplickTheme.Spacing.sm)
    }

    private var consentText: some View {
        VStack(spacing: 4) {
            Text(languageService.text(.legalConsentPrefix))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: SplickTheme.Spacing.xs) {
                Button(action: onOpenTerms) {
                    Text(languageService.text(.legalTermsTitle))
                        .font(SplickTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                }
                .buttonStyle(.plain)

                Text("&")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)

                Button(action: onOpenPrivacy) {
                    Text(languageService.text(.legalPrivacyTitle))
                        .font(SplickTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
import Storage

#Preview("Footer with checkbox") {
    struct PreviewWrapper: View {
        @StateObject private var languageService = LanguageService(userDefaults: UserDefaultsService())
        @State private var accepted = false

        var body: some View {
            LegalLinksFooter(
                hasAcceptedTerms: $accepted,
                showsConsentCheckbox: true,
                onOpenTerms: {},
                onOpenPrivacy: {}
            )
            .padding()
            .environmentObject(languageService)
            .languageService(languageService)
        }
    }
    return PreviewWrapper()
}
#endif
