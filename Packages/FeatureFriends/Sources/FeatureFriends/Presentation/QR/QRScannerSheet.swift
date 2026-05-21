import SwiftUI
import DesignSystem

enum QRScannerMode {
    case addFriend
    case joinGroup
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

    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?
    @State private var manualCode = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SplickTheme.Spacing.md) {
                    cameraSection

                    if mode == .addFriend, let myQrContext {
                        MyQRPreviewSection(
                            username: myQrContext.username,
                            displayName: myQrContext.displayName,
                            avatarURL: myQrContext.avatarURL,
                            generateMyQrUseCase: myQrContext.generateMyQrUseCase
                        )
                    }

                    manualEntrySection
                }
                .padding(.top, SplickTheme.Spacing.md)
                .padding(.bottom, SplickTheme.Spacing.lg)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
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
            Text("Trên Simulator không có camera. Dán mã QR bên dưới hoặc dùng máy thật để quét.")
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SplickTheme.Colors.secondaryBackground)
    }

    private var manualEntrySection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            Text("Hoặc dán mã thủ công")
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            TextField(manualPlaceholder, text: $manualCode)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            SplickButton("Dùng mã này", isDisabled: manualCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                onScan(manualCode)
                dismiss()
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
    }

    private var navigationTitle: String {
        switch mode {
        case .addFriend: return "Quét mã QR"
        case .joinGroup: return "Quét mã nhóm"
        }
    }

    private var manualPlaceholder: String {
        switch mode {
        case .addFriend: return "Dán payload QR hoặc splick://friend/username"
        case .joinGroup: return "splick://group/invite-code"
        }
    }
}
