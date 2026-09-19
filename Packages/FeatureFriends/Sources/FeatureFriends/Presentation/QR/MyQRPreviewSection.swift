import SwiftUI
import DesignSystem
import Localization

/// Compact capsule action used on the QR scanner bottom bar (matches friends tab shortcuts).
struct QRScannerOptionRow: View {
    let icon: String
    let title: String
    var action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        VStack(spacing: SplickTheme.Spacing.xxxs) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
                .lineSpacing(0)
        }
        .padding(.top, SplickTheme.Spacing.xxs)
        .padding(.bottom, SplickTheme.Spacing.xs)
        .padding(.horizontal, SplickTheme.Spacing.xs)
        .frame(maxWidth: .infinity)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(Capsule(style: .continuous))
    }
}

/// Opens the full “my QR” sheet from the scan screen.
struct MyQRAccessButton: View {
    let username: String
    let displayName: String
    let avatarURL: URL?
    let generateMyQrUseCase: GenerateMyQrUseCaseProtocol

    @EnvironmentObject private var languageService: LanguageService
    @State private var showMyQRSheet = false

    var body: some View {
        QRScannerOptionRow(
            icon: "qrcode",
            title: languageService.text(.friendsMyQRPreviewTitle),
            action: { showMyQRSheet = true }
        )
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
