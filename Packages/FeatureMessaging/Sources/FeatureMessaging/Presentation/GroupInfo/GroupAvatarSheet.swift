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
    @State private var cropTransform = AvatarCropTransform()
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let previewDiameter: CGFloat = 192

    var body: some View {
        NavigationStack {
            VStack(spacing: SplickTheme.Spacing.lg) {
                if let previewImage {
                    AvatarCropEditor(sourceImage: previewImage, transform: $cropTransform)
                        .padding(.horizontal, SplickTheme.Spacing.md)

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Text(languageService.text(.messagingGroupChangePhoto))
                            .font(SplickTheme.Typography.headline)
                            .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    }
                    .buttonStyle(.plain)
                } else {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        avatarPreview
                    }
                }

                Text(
                    languageService.text(
                        previewImage == nil
                            ? .messagingGroupChangeAvatarHint
                            : .messagingGroupAvatarAlignHint
                    )
                )
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SplickTheme.Spacing.md)

                if let errorMessage {
                    Text(errorMessage)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SplickTheme.Spacing.md)
                }

                SplickButton(
                    languageService.text(.commonSave),
                    isLoading: isSaving,
                    isDisabled: isSaving || previewImage == nil || cropTransform.crop.width < 2
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
            .onChange(of: selectedPhotoItem) { _ in
                Task { await loadSelectedPhoto() }
            }
        }
    }

    @ViewBuilder
    private var avatarPreview: some View {
        ZStack(alignment: .bottomTrailing) {
            AvatarView(imageURL: currentAvatarURL, name: groupName, size: .large)
                .scaleEffect(previewDiameter / 72)
                .frame(width: previewDiameter, height: previewDiameter)
                .clipShape(Circle())

            Image(systemName: "camera.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .padding(10)
                .background(Circle().fill(SplickTheme.Colors.primaryGradientStart))
                .offset(x: 8, y: 8)
        }
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhotoItem else {
            previewImage = nil
            cropTransform = AvatarCropTransform()
            return
        }
        guard let data = try? await selectedPhotoItem.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            errorMessage = languageService.text(.messagingGroupChangeAvatarLoadError)
            return
        }
        previewImage = downsampled(image)
        cropTransform = AvatarCropTransform()
        errorMessage = nil
    }

    private func save() async {
        guard let previewImage else {
            errorMessage = languageService.text(.messagingGroupChangeAvatarLoadError)
            return
        }
        let cropped = AvatarCropRenderer.render(source: previewImage, transform: cropTransform)
        guard let data = cropped.jpegData(compressionQuality: 0.85) else {
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

    private func downsampled(_ image: UIImage, maxSide: CGFloat = 2048) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return image }
        let scale = maxSide / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
