import SwiftUI
import Localization
import SplickDomain

public struct PaymentProfileSummaryView: View {
    let profile: PaymentProfile
    let title: String

    @EnvironmentObject private var languageService: LanguageService

    public init(profile: PaymentProfile, title: String) {
        self.profile = profile
        self.title = title
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(title)
                .font(SplickTheme.Typography.headline)

            if let url = profile.qrImageURL {
                SplickExpandableRemoteImage(
                    url: url,
                    maxHeight: 180,
                    accessibilityLabel: languageService.text(.profilePaymentQrSection)
                )
            }

            if profile.hasDisplayableBankFields {
                bankDetailsBlock
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SplickTheme.Spacing.md)
        .background(SplickTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))
    }

    private var bankDetailsBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let accountName = profile.accountName {
                Text(accountName)
                    .font(SplickTheme.Typography.body)
            }
            if let accountNumber = profile.accountNumber {
                Text(accountNumber)
                    .font(SplickTheme.Typography.callout.monospaced())
            }
            if let bankName = profile.bankName {
                Text(bankName)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
        }
    }
}
