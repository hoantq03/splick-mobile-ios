import SwiftUI
import PhotosUI
import DesignSystem
import Common
import Localization
import SplickDomain

public struct EditProfileView: View {
    @StateObject private var viewModel: EditProfileViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    private let onProfileUpdated: (User) -> Void

    public init(
        viewModel: @autoclosure @escaping () -> EditProfileViewModel,
        onProfileUpdated: @escaping (User) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onProfileUpdated = onProfileUpdated
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: SplickTheme.Spacing.lg) {
                PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                    profileAvatar
                }
                .onChange(of: viewModel.selectedPhotoItem) { _ in
                    Task { await viewModel.onPhotoItemChanged() }
                }

                Text(languageService.text(.profileAvatarChangeHint))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                SplickTextField(
                    languageService.text(.authDisplayName),
                    text: $viewModel.displayName,
                    icon: "person"
                )
                .textInputAutocapitalization(.words)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                        .multilineTextAlignment(.center)
                }

                SplickButton(
                    languageService.text(.commonSave),
                    isLoading: viewModel.state.isLoading,
                    isDisabled: viewModel.state.isLoading
                ) {
                    Task {
                        if let user = await viewModel.save() {
                            onProfileUpdated(user)
                            dismiss()
                        }
                    }
                }
            }
            .padding(SplickTheme.Spacing.md)
        }
        .navigationTitle(languageService.text(.profileEdit))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(languageService.text(.commonCancel)) { dismiss() }
            }
        }
    }

    @ViewBuilder
    private var profileAvatar: some View {
        if let preview = viewModel.previewImage {
            Image(uiImage: preview)
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 96)
                .clipShape(Circle())
        } else {
            AvatarView(imageURL: viewModel.existingAvatarURL, name: viewModel.displayName, size: .large)
        }
    }
}
