import SwiftUI
import DesignSystem
import Localization

struct JoinGroupSheet: View {
    @ObservedObject var viewModel: JoinGroupViewModel
    @EnvironmentObject private var languageService: LanguageService
    @State private var showQRScanner = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: SplickTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
                    Text(languageService.text(.friendsGroupInviteCode))
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)

                    TextField("e.g. roommates-q7", text: $viewModel.inviteCode)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                SplickButton(
                    languageService.text(.friendsJoinGroupAction),
                    isLoading: viewModel.isLoading,
                    isDisabled: viewModel.inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    Task { await viewModel.joinByCode() }
                }

                Button {
                    showQRScanner = true
                } label: {
                    Label(languageService.text(.friendsScanGroupQR), systemImage: "qrcode.viewfinder")
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
            .navigationTitle(languageService.text(.friendsJoinGroupTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.friendsClose)) { dismiss() }
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
