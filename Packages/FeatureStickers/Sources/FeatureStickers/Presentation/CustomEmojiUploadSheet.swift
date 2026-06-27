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
    @EnvironmentObject private var emojiStore: CustomEmojiStore

    private let currentUserId: UUID?
    private let customEmojiFetcher: any CustomEmojiFetching
    private let uploadMediaUseCase: UploadMediaUseCaseProtocol
    private let addEmojiUseCase: AddUserCustomEmojiUseCaseProtocol
    private let deleteEmojiUseCase: DeleteUserCustomEmojiUseCaseProtocol

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var alias = ""
    @State private var isUploading = false
    @State private var errorMessage: String?

    public init(
        currentUserId: UUID?,
        customEmojiFetcher: any CustomEmojiFetching,
        uploadMediaUseCase: UploadMediaUseCaseProtocol,
        addEmojiUseCase: AddUserCustomEmojiUseCaseProtocol,
        deleteEmojiUseCase: DeleteUserCustomEmojiUseCaseProtocol
    ) {
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
            await emojiStore.load(fetcher: customEmojiFetcher)
        }
    }

    private var uploadSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(languageService.text(.feedCustomEmojiUploadSectionTitle))
                .font(SplickTheme.Typography.headline)

            HStack(spacing: SplickTheme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(SplickTheme.Colors.secondaryBackground)
                        .frame(width: 96, height: 96)
                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 75, height: 75)
                            .clipShape(Circle())
                            .frame(width: 88, height: 88)
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
                    .onChange(of: selectedPhotoItem) { item in
                        Task { await loadPreview(from: item) }
                    }

                    TextField(
                        languageService.text(.feedCustomEmojiShortcodePlaceholder),
                        text: $alias
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

            let emojis = currentUserId.map { emojiStore.emojis(ownedBy: $0) } ?? emojiStore.allEmojis
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
                            EmojiView(value: emoji.colonCode, size: 44)
                            Text(":\(emoji.shortcode):")
                                .font(.caption2)
                                .lineLimit(1)
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

    private var canUpload: Bool {
        previewImage != nil && !isUploading
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
        guard var image = previewImage else { return }
        isUploading = true
        defer { isUploading = false }

        do {
            let resolvedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
            if !resolvedAlias.isEmpty {
                guard CustomEmojiShortcodeValidator.isValid(resolvedAlias) else {
                    throw CustomEmojiError.invalidShortcode
                }
            }
            let (data, mimeType) = try CustomEmojiImageProcessor.prepareUploadData(from: image)
            let upload = try await uploadMediaUseCase.execute(
                imageData: data,
                mimeType: mimeType,
                purpose: MediaUploadPurpose.userCustomEmoji,
                groupId: nil
            )
            let emoji = try await addEmojiUseCase.execute(
                alias: resolvedAlias.isEmpty ? nil : resolvedAlias,
                mediaId: upload.id
            )
            emojiStore.upsert(emoji)
            alias = ""
            previewImage = nil
            selectedPhotoItem = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func delete(_ emoji: CustomEmoji) async {
        do {
            try await deleteEmojiUseCase.execute(emojiId: emoji.id)
            emojiStore.remove(emojiId: emoji.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
