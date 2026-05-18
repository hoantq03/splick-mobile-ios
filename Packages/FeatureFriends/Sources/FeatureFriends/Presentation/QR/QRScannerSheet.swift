import SwiftUI
import DesignSystem

enum QRScannerMode {
    case addFriend
    case joinGroup
}

struct QRScannerSheet: View {
    let mode: QRScannerMode
    let onScan: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?
    @State private var manualCode = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: SplickTheme.Spacing.md) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
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
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium, style: .continuous))
                    .padding(.horizontal, SplickTheme.Spacing.md)
                }

                VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
                    Text("Or paste code manually")
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)

                    TextField(manualPlaceholder, text: $manualCode)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SplickButton("Use code", isDisabled: manualCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                        onScan(manualCode)
                        dismiss()
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.md)

                Spacer()
            }
            .padding(.top, SplickTheme.Spacing.md)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .addFriend: return "Scan friend QR"
        case .joinGroup: return "Scan group QR"
        }
    }

    private var manualPlaceholder: String {
        switch mode {
        case .addFriend: return "splick://friend/username"
        case .joinGroup: return "splick://group/invite-code"
        }
    }
}
