import SwiftUI
import DesignSystem

struct JoinGroupSheet: View {
    @ObservedObject var viewModel: JoinGroupViewModel
    @State private var showQRScanner = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: SplickTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
                    Text("Group invite code")
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)

                    TextField("e.g. roommates-q7", text: $viewModel.inviteCode)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                SplickButton(
                    "Join group",
                    isLoading: viewModel.isLoading,
                    isDisabled: viewModel.inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    Task { await viewModel.joinByCode() }
                }

                Button {
                    showQRScanner = true
                } label: {
                    Label("Scan QR code", systemImage: "qrcode.viewfinder")
                        .font(SplickTheme.Typography.headline)
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SplickTheme.Spacing.sm)
                        .background(SplickTheme.Colors.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium, style: .continuous))
                }
                .buttonStyle(.plain)

                if let success = viewModel.successMessage {
                    Text(success)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.success)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                }

                Spacer()
            }
            .padding(SplickTheme.Spacing.md)
            .navigationTitle("Join group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showQRScanner) {
                QRScannerSheet(mode: .joinGroup) { code in
                    Task { await viewModel.joinFromQR(code) }
                }
            }
        }
    }
}
