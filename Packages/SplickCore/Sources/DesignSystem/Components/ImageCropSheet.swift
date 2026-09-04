import SwiftUI
import PhotosUI
import UIKit
import Localization

public struct ImageCropSheet<EmptyContent: View, Accessory: View>: View {
    let title: String
    let emptyHint: String
    let alignHint: String
    let changePhotoTitle: String
    let loadErrorText: String
    let saveTitle: String
    let outputSize: CGFloat
    let onSave: (UIImage) async throws -> Void
    let emptyContent: EmptyContent
    let accessory: Accessory

    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @State private var sourceImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var cropTransform = ImageCropTransform()
    @State private var isSaving = false
    @State private var errorMessage: String?

    public init(
        title: String,
        emptyHint: String,
        alignHint: String,
        changePhotoTitle: String,
        loadErrorText: String,
        saveTitle: String,
        initialImage: UIImage? = nil,
        outputSize: CGFloat = ImageCropRenderer.avatarOutputSize,
        onSave: @escaping (UIImage) async throws -> Void,
        @ViewBuilder emptyContent: () -> EmptyContent,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.emptyHint = emptyHint
        self.alignHint = alignHint
        self.changePhotoTitle = changePhotoTitle
        self.loadErrorText = loadErrorText
        self.saveTitle = saveTitle
        self.outputSize = outputSize
        self.onSave = onSave
        self.emptyContent = emptyContent()
        self.accessory = accessory()
        _sourceImage = State(initialValue: initialImage)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: SplickTheme.Spacing.lg) {
                if let sourceImage {
                    ImageCropEditor(
                        sourceImage: sourceImage,
                        transform: $cropTransform
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, SplickTheme.Spacing.md)

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Text(changePhotoTitle)
                            .font(SplickTheme.Typography.headline)
                            .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    }
                    .buttonStyle(.plain)
                } else {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        emptyContent
                    }
                }

                Text(sourceImage == nil ? emptyHint : alignHint)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SplickTheme.Spacing.md)

                accessory
                    .padding(.horizontal, SplickTheme.Spacing.md)

                if let errorMessage {
                    Text(errorMessage)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SplickTheme.Spacing.md)
                }

                SplickButton(
                    saveTitle,
                    isLoading: isSaving,
                    isDisabled: isSaving || sourceImage == nil || cropTransform.crop.width < 2
                ) {
                    Task { await save() }
                }
                .padding(.horizontal, SplickTheme.Spacing.md)

                Spacer(minLength: 0)
            }
            .padding(.top, SplickTheme.Spacing.lg)
            .navigationTitle(title)
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
        .presentationDetents([.large])
        .interactiveDismissDisabled(isSaving)
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhotoItem else { return }
        guard let data = try? await selectedPhotoItem.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            errorMessage = loadErrorText
            return
        }
        sourceImage = ImageCropRenderer.downsampled(image)
        cropTransform = ImageCropTransform()
        errorMessage = nil
    }

    private func save() async {
        guard let sourceImage else {
            errorMessage = loadErrorText
            return
        }
        let cropped = ImageCropRenderer.render(
            source: sourceImage,
            transform: cropTransform,
            outputSize: outputSize
        )
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await onSave(cropped)
            dismiss()
        } catch {
            errorMessage = languageService.localizedMessage(for: error)
        }
    }
}

public extension ImageCropSheet where EmptyContent == EmptyView, Accessory == EmptyView {
    init(
        title: String,
        emptyHint: String,
        alignHint: String,
        changePhotoTitle: String,
        loadErrorText: String,
        saveTitle: String,
        initialImage: UIImage,
        outputSize: CGFloat = ImageCropRenderer.avatarOutputSize,
        onSave: @escaping (UIImage) async throws -> Void
    ) {
        self.init(
            title: title,
            emptyHint: emptyHint,
            alignHint: alignHint,
            changePhotoTitle: changePhotoTitle,
            loadErrorText: loadErrorText,
            saveTitle: saveTitle,
            initialImage: initialImage,
            outputSize: outputSize,
            onSave: onSave,
            emptyContent: { EmptyView() },
            accessory: { EmptyView() }
        )
    }
}

public extension ImageCropSheet where Accessory == EmptyView {
    init(
        title: String,
        emptyHint: String,
        alignHint: String,
        changePhotoTitle: String,
        loadErrorText: String,
        saveTitle: String,
        initialImage: UIImage? = nil,
        outputSize: CGFloat = ImageCropRenderer.avatarOutputSize,
        onSave: @escaping (UIImage) async throws -> Void,
        @ViewBuilder emptyContent: () -> EmptyContent
    ) {
        self.init(
            title: title,
            emptyHint: emptyHint,
            alignHint: alignHint,
            changePhotoTitle: changePhotoTitle,
            loadErrorText: loadErrorText,
            saveTitle: saveTitle,
            initialImage: initialImage,
            outputSize: outputSize,
            onSave: onSave,
            emptyContent: emptyContent,
            accessory: { EmptyView() }
        )
    }
}

public extension ImageCropSheet where EmptyContent == EmptyView {
    init(
        title: String,
        emptyHint: String,
        alignHint: String,
        changePhotoTitle: String,
        loadErrorText: String,
        saveTitle: String,
        initialImage: UIImage,
        outputSize: CGFloat = ImageCropRenderer.avatarOutputSize,
        onSave: @escaping (UIImage) async throws -> Void,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.init(
            title: title,
            emptyHint: emptyHint,
            alignHint: alignHint,
            changePhotoTitle: changePhotoTitle,
            loadErrorText: loadErrorText,
            saveTitle: saveTitle,
            initialImage: initialImage,
            outputSize: outputSize,
            onSave: onSave,
            emptyContent: { EmptyView() },
            accessory: accessory
        )
    }
}
