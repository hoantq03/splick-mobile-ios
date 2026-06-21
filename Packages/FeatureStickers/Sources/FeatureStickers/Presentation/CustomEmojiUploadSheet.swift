import SwiftUI
import PhotosUI
import Common
import DesignSystem
import FeatureMedia
import Localization
import SplickDomain

public struct CustomEmojiUploadSheet: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.customEmojiStore) private var emojiStore

    private let groupId: UUID
    private let currentUserId: UUID?
    private let customEmojiFetcher: any CustomEmojiFetching
    private let uploadMediaUseCase: UploadMediaUseCaseProtocol
    private let addEmojiUseCase: AddGroupCustomEmojiUseCaseProtocol
    private let deleteEmojiUseCase: DeleteGroupCustomEmojiUseCaseProtocol

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var shortcode = ""
    @State private var isUploading = false
    @State private var errorMessage: String?

    public init(
        groupId: UUID,
        currentUserId: UUID?,
        customEmojiFetcher: any CustomEmojiFetching,
        uploadMediaUseCase: UploadMediaUseCaseProtocol,
        addEmojiUseCase: AddGroupCustomEmojiUseCaseProtocol,
        deleteEmojiUseCase: DeleteGroupCustomEmojiUseCaseProtocol
    ) {
        self.groupId = groupId
        self.currentUserId = currentUserId
        self.customEmojiFetcher = customEmojiFetcher
        self.uploadMediaUseCase = uploadMediaUseCase
        self.addEmojiUseCase = addEmojiUseCase
        self.deleteEmojiUseCase = deleteEmojiUseCase
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                    uploadSection
                    existingSection
                }
                .padding(SplickTheme.Spacing.md)
            }
            .background(SplickTheme.Colors.background)
            .navigationTitle(languageService.text(.feedCustomEmojiUploadTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) { dismiss() }
                }
            }
            .alert(
                languageService.text(.commonError),
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button(languageService.text(.commonOK), role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            await emojiStore.load(groupId: groupId, fetcher: customEmojiFetcher)
        }
    }

    private var uploadSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(languageService.text(.feedCustomEmojiUploadSectionTitle))
                .font(SplickTheme.Typography.headline)

            HStack(spacing: SplickTheme.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(SplickTheme.Colors.secondaryBackground)
                        .frame(width: 96, height: 96)
                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                    } else {
                        Image(systemName: "photo.badge.plus")
                            .font(.title2)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Text(languageService.text(.feedCustomEmojiChoosePhoto))
                    }
                    .onChange(of: selectedPhotoItem) { _, item in
                        Task { await loadPreview(from: item) }
                    }

                    TextField(
                        languageService.text(.feedCustomEmojiShortcodePlaceholder),
                        text: $shortcode
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                    Button {
                        Task { await upload() }
                    } label: {
                        if isUploading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(languageService.text(.feedCustomEmojiUploadAction))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canUpload)
                }
            }
        }
    }

    private var existingSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(languageService.text(.feedCustomEmojiExistingTitle))
                .font(SplickTheme.Typography.headline)

            let emojis = emojiStore.emojis(for: groupId)
            if emojis.isEmpty {
                Text(languageService.text(.feedCustomEmojiEmpty))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                    spacing: 10
                ) {
                    ForEach(emojis) { emoji in
                        VStack(spacing: 4) {
                            EmojiView(value: emoji.colonCode, groupId: groupId, size: 44)
                            Text(":\(emoji.shortcode):")
                                .font(.caption2)
                                .lineLimit(1)
                            if canDelete(emoji) {
                                Button(role: .destructive) {
                                    Task { await delete(emoji) }
                                } label: {
                                    Text(languageService.text(.profilePaymentDelete))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var canUpload: Bool {
        previewImage != nil
            && CustomEmojiShortcodeValidator.isValid(shortcode)
            && !isUploading
    }

    private func canDelete(_ emoji: CustomEmoji) -> Bool {
        guard let currentUserId else { return false }
        return emoji.createdBy == currentUserId
    }

    @MainActor
    private func loadPreview(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else {
            previewImage = nil
            return
        }
        previewImage = image
    }

    @MainActor
    private func upload() async {
        guard let previewImage else { return }
        isUploading = true
        defer { isUploading = false }

        do {
            let normalized = CustomEmojiShortcodeValidator.normalize(shortcode)
            guard CustomEmojiShortcodeValidator.isValid(normalized) else {
                throw CustomEmojiError.invalidShortcode
            }
            let (data, mimeType) = try CustomEmojiImageProcessor.prepareUploadData(from: previewImage)
            let upload = try await uploadMediaUseCase.execute(
                imageData: data,
                mimeType: mimeType,
                purpose: .groupCustomEmoji,
                groupId: groupId
            )
            let emoji = try await addEmojiUseCase.execute(
                groupId: groupId,
                shortcode: normalized,
                mediaId: upload.id
            )
            emojiStore.upsert(emoji)
            shortcode = ""
            previewImage = nil
            selectedPhotoItem = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func delete(_ emoji: CustomEmoji) async {
        do {
            try await deleteEmojiUseCase.execute(groupId: groupId, emojiId: emoji.id)
            emojiStore.remove(emojiId: emoji.id, from: groupId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
