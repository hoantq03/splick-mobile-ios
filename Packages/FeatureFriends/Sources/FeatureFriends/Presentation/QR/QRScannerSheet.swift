import SwiftUI
import DesignSystem
import Localization

enum QRScannerMode {
    case addFriend
    case joinGroup
    /// Single scanner for friend QR and group invite QR.
    case unified
}

struct QRScannerMyQrContext {
    let username: String
    let displayName: String
    let avatarURL: URL?
    let generateMyQrUseCase: GenerateMyQrUseCaseProtocol
}

struct QRScannerSheet: View {
    let mode: QRScannerMode
    let onScan: (String) -> Void
    var myQrContext: QRScannerMyQrContext?

    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: SplickTheme.Spacing.md) {
                cameraSection

                if (mode == .addFriend || mode == .unified), let myQrContext {
                    MyQRAccessButton(
                        username: myQrContext.username,
                        displayName: myQrContext.displayName,
                        avatarURL: myQrContext.avatarURL,
                        generateMyQrUseCase: myQrContext.generateMyQrUseCase
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(.top, SplickTheme.Spacing.md)
            .padding(.bottom, SplickTheme.Spacing.lg)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.friendsClose)) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var cameraSection: some View {
        Group {
            if let errorMessage {
                cameraUnavailableView(message: errorMessage)
            } else {
                QRCodeScannerView(
                    onCodeScanned: { code in
                        onScan(code)
                        dismiss()
                    },
                    onError: { message in
                        errorMessage = message
                    }
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium, style: .continuous))
        .padding(.horizontal, SplickTheme.Spacing.md)
    }

    private func cameraUnavailableView(message: String) -> some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            Image(systemName: "camera.fill")
                .font(.system(size: 36))
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            Text(message)
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            #if targetEnvironment(simulator)
            Text(languageService.text(.friendsScanSimulatorHint))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SplickTheme.Colors.secondaryBackground)
    }

    private var navigationTitle: String {
        switch mode {
        case .addFriend: return languageService.text(.friendsScanQRAddFriend)
        case .joinGroup: return languageService.text(.friendsScanQRJoinGroup)
        case .unified: return languageService.text(.friendsScanQRUnified)
        }
    }
}
