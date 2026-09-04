import SwiftUI
import DesignSystem
import Localization
import SplickDomain

public struct ChangeUsernameSheet: View {
    @StateObject private var viewModel: ChangeUsernameSheetViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss

    private let onSaved: (User) -> Void

    public init(
        viewModel: ChangeUsernameSheetViewModel,
        onSaved: @escaping (User) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSaved = onSaved
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: SplickTheme.Spacing.lg) {
                SplickTextField(
                    languageService.text(.authUsername),
                    text: $viewModel.usernameDraft,
                    errorMessage: viewModel.usernameError,
                    icon: "at",
                    validationStatus: viewModel.usernameStatus
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: viewModel.usernameDraft) { _ in
                    viewModel.onUsernameChanged()
                }

                if let saveError = viewModel.saveError {
                    Text(saveError)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                        .multilineTextAlignment(.center)
                }

                SplickButton(
                    languageService.text(.profileSave),
                    isLoading: viewModel.isSaving,
                    isDisabled: !viewModel.canSave
                ) {
                    Task {
                        if let user = await viewModel.save() {
                            onSaved(user)
                            dismiss()
                        }
                    }
                }
            }
            .padding(SplickTheme.Spacing.md)
            .navigationTitle(languageService.text(.profileChangeUsername))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.prepareForPresentation()
            }
        }
        .presentationDetents([.medium])
    }
}
