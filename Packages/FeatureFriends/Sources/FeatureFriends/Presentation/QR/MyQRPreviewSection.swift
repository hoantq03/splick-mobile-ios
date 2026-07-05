import SwiftUI
import DesignSystem
import Localization

/// Opens the full “my QR” sheet from the scan screen.
struct MyQRAccessButton: View {
    let username: String
    let displayName: String
    let avatarURL: URL?
    let generateMyQrUseCase: GenerateMyQrUseCaseProtocol

    @EnvironmentObject private var languageService: LanguageService
    @State private var showMyQRSheet = false

    var body: some View {
        Button {
            showMyQRSheet = true
        } label: {
            HStack(spacing: SplickTheme.Spacing.sm) {
                Image(systemName: "qrcode")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    .frame(width: 36, height: 36)
                    .background(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small, style: .continuous))

                Text(languageService.text(.friendsMyQRPreviewTitle))
                    .font(SplickTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(SplickTheme.Colors.textPrimary)

                Spacer(minLength: SplickTheme.Spacing.xs)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
            }
            .padding(SplickTheme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(SplickTheme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, SplickTheme.Spacing.md)
        .sheet(isPresented: $showMyQRSheet) {
            MyQRSheet(
                username: username,
                displayName: displayName,
                avatarURL: avatarURL,
                generateMyQrUseCase: generateMyQrUseCase
            )
        }
    }
}
