import SwiftUI
import PhotosUI
import DesignSystem
import FeatureMedia
import SplickDomain

struct EditGroupSheet: View {
    @StateObject private var viewModel: EditGroupViewModel
    @Environment(\.dismiss) private var dismiss
    let onSaved: (SplickDomain.Group) -> Void

    init(
        group: SplickDomain.Group,
        updateGroupUseCase: UpdateGroupUseCaseProtocol,
        updateGroupAvatarUseCase: UpdateGroupAvatarUseCaseProtocol,
        uploadGroupAvatarUseCase: UploadGroupAvatarUseCaseProtocol,
        onSaved: @escaping (SplickDomain.Group) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: EditGroupViewModel(
                group: group,
                updateGroupUseCase: updateGroupUseCase,
                updateGroupAvatarUseCase: updateGroupAvatarUseCase,
                uploadGroupAvatarUseCase: uploadGroupAvatarUseCase
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

                    SplickTextField("Tên nhóm", text: $viewModel.name, icon: "person.3")

                    VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
                        Text("Mô tả")
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                        TextField("Mô tả nhóm (tuỳ chọn)", text: $viewModel.description, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.error)
                    }

                    SplickButton("Lưu", isLoading: viewModel.isSaving, isDisabled: viewModel.isSaving) {
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
            .navigationTitle("Chỉnh sửa nhóm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
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
