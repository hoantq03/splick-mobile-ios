import SwiftUI
import DesignSystem
import Localization

struct AddFriendSheet: View {
    @ObservedObject var viewModel: AddFriendViewModel
    @EnvironmentObject private var languageService: LanguageService
    @State private var showQRScanner = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: SplickTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
                    Text(languageService.text(.friendsUsername))
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)

                    TextField("e.g. namtran", text: $viewModel.username)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
                    Text(languageService.text(.friendsMessageOptional))
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)

                    TextField("Say hi...", text: $viewModel.message, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...5)
                }

                SplickButton(
                    languageService.text(.friendsAddFriendAction),
                    isLoading: viewModel.isLoading,
                    isDisabled: viewModel.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    Task { await viewModel.addByUsername() }
                }

                Button {
                    showQRScanner = true
                } label: {
                    Label(languageService.text(.friendsScanQRAddFriend), systemImage: "qrcode.viewfinder")
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
            .navigationTitle(languageService.text(.friendsAddFriendTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.friendsClose)) { dismiss() }
                }
            }
            .sheet(isPresented: $showQRScanner) {
                QRScannerSheet(mode: .addFriend) { code in
                    Task { await viewModel.addFromQR(code) }
                }
            }
        }
    }
}
