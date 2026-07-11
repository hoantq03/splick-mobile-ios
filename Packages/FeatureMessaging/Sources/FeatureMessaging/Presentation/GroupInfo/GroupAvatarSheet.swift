import SwiftUI
import PhotosUI
import UIKit
import DesignSystem
import Localization

struct GroupAvatarSheet: View {
    let groupName: String
    let currentAvatarURL: URL?
    let onSave: (Data) async throws -> String

    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let previewDiameter: CGFloat = 192

    var body: some View {
        NavigationStack {
            VStack(spacing: SplickTheme.Spacing.lg) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    avatarPreview
                }
                .onChange(of: selectedPhotoItem) { _ in
                    Task { await loadSelectedPhoto() }
                }

                Text(languageService.text(.messagingGroupChangeAvatarHint))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                if let errorMessage {
                    Text(errorMessage)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                        .multilineTextAlignment(.center)
                }

                SplickButton(
                    languageService.text(.commonSave),
                    isLoading: isSaving,
                    isDisabled: isSaving || previewImage == nil
                ) {
                    Task { await save() }
                }
                .padding(.horizontal, SplickTheme.Spacing.md)

                Spacer(minLength: 0)
            }
            .padding(.top, SplickTheme.Spacing.lg)
            .navigationTitle(languageService.text(.messagingGroupChangeAvatar))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var avatarPreview: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    AvatarView(imageURL: currentAvatarURL, name: groupName, size: .large)
                        .scaleEffect(previewDiameter / 72)
                }
            }
            .frame(width: previewDiameter, height: previewDiameter)
            .clipShape(Circle())

            if previewImage == nil {
                Image(systemName: "camera.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Circle().fill(SplickTheme.Colors.primaryGradientStart))
                    .offset(x: 8, y: 8)
            }
        }
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhotoItem else {
            previewImage = nil
            return
        }
        guard let data = try? await selectedPhotoItem.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            errorMessage = languageService.text(.messagingGroupChangeAvatarLoadError)
            return
        }
        previewImage = image
        errorMessage = nil
    }

    private func save() async {
        guard let previewImage,
              let data = previewImage.jpegData(compressionQuality: 0.9) else {
            errorMessage = languageService.text(.messagingGroupChangeAvatarLoadError)
            return
        }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            _ = try await onSave(data)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
