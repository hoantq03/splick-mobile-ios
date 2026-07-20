import SwiftUI
import PhotosUI
import DesignSystem
import FeatureMedia
import Localization
import SplickDomain

struct EditGroupSheet: View {
    @StateObject private var viewModel: EditGroupViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    let onSaved: (SplickDomain.Group) -> Void

    init(
        group: SplickDomain.Group,
        updateGroupUseCase: UpdateGroupUseCaseProtocol,
        updateGroupAvatarUseCase: UpdateGroupAvatarUseCaseProtocol,
        uploadGroupAvatarUseCase: UploadGroupAvatarUseCaseProtocol,
        languageService: LanguageService,
        onSaved: @escaping (SplickDomain.Group) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: EditGroupViewModel(
                group: group,
                updateGroupUseCase: updateGroupUseCase,
                updateGroupAvatarUseCase: updateGroupAvatarUseCase,
                uploadGroupAvatarUseCase: uploadGroupAvatarUseCase,
                languageService: languageService
            )
        )
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SplickTheme.Spacing.lg) {
                    PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                        groupAvatarPreview
                    }
                    .onChange(of: viewModel.selectedPhotoItem) { _ in
                        Task { await viewModel.onPhotoItemChanged() }
                    }

                    SplickTextField(languageService.text(.friendsGroupName), text: $viewModel.name, icon: "person.3")

                    VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
                        Text(languageService.text(.friendsGroupDescription))
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                        TextField(
                            languageService.text(.friendsGroupDescriptionPlaceholder),
                            text: $viewModel.description,
                            axis: .vertical
                        )
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.error)
                    }

                    SplickButton(
                        languageService.text(.commonSave),
                        isLoading: viewModel.isSaving,
                        isDisabled: viewModel.isSaving
                    ) {
                        Task {
                            if let group = await viewModel.save() {
                                onSaved(group)
                                dismiss()
                            }
                        }
                    }
                }
                .padding(SplickTheme.Spacing.md)
            }
            .navigationTitle(languageService.text(.friendsEditGroupTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var groupAvatarPreview: some View {
        if let preview = viewModel.previewImage {
            Image(uiImage: preview)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.title)
                .frame(width: 80, height: 80)
                .background(SplickTheme.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
