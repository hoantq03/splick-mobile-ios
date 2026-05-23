import SwiftUI
import PhotosUI
import DesignSystem
import Common
import SplickDomain

public struct EditProfileView: View {
    @StateObject private var viewModel: EditProfileViewModel
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

                SplickTextField(
                    "Display name",
                    text: $viewModel.displayName,
                    icon: "person"
                )
                .textInputAutocapitalization(.words)

                SplickTextField(
                    "Avatar URL (optional)",
                    text: $viewModel.avatarUrlText,
                    icon: "link"
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                        .multilineTextAlignment(.center)
                }

                SplickButton(
                    "Save",
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
        .navigationTitle("Edit profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var profileAvatar: some View {
        if let preview = viewModel.previewImage {
            Image(uiImage: preview)
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 96)
                .clipShape(Circle())
        } else if let urlText = viewModel.avatarUrlText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                  let url = URL(string: urlText) {
            AvatarView(imageURL: url, name: viewModel.displayName, size: .large)
        } else {
            AvatarView(imageURL: nil, name: viewModel.displayName, size: .large)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
