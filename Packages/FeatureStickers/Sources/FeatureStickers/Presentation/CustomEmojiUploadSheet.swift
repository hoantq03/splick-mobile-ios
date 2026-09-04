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
    @State private var composerDraft: ComposerImageDraft?
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
            .navigationTitle(languageService.text(.stickersYourEmoji))
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
        .sheet(item: $composerDraft) { draft in
            CustomEmojiComposerSheet(
                sourceImage: draft.image,
                currentUserId: currentUserId,
                uploadMediaUseCase: uploadMediaUseCase,
                addEmojiUseCase: addEmojiUseCase
            )
            .environmentObject(languageService)
            .environmentObject(emojiStore)
        }
        .task {
            await emojiStore.load(fetcher: customEmojiFetcher)
        }
    }

    private var uploadSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(languageService.text(.stickersUploadYourEmoji))
                .font(SplickTheme.Typography.headline)

            Text(languageService.text(.stickersPersonalEmojiHint))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            HStack(spacing: SplickTheme.Spacing.md) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Text(languageService.text(.feedCustomEmojiChoosePhoto))
                        .font(SplickTheme.Typography.headline)
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                }
                .onChange(of: selectedPhotoItem) { item in
                    Task { await openComposer(from: item) }
                }
            }
        }
    }

    private var existingSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(languageService.text(.stickersYourEmoji))
                .font(SplickTheme.Typography.headline)

            let emojis = currentUserId.map { emojiStore.emojis(ownedBy: $0) } ?? emojiStore.allEmojis
            if emojis.isEmpty {
                Text(languageService.text(.stickersPersonalEmojiEmpty))
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

    @MainActor
    private func openComposer(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else {
            selectedPhotoItem = nil
            return
        }
        selectedPhotoItem = nil
        composerDraft = ComposerImageDraft(image: image)
    }

    @MainActor
    private func delete(_ emoji: CustomEmoji) async {
        do {
            try await deleteEmojiUseCase.execute(emojiId: emoji.id)
            emojiStore.remove(emojiId: emoji.id)
        } catch {
            errorMessage = languageService.localizedMessage(for: error)
        }
    }
}

private struct ComposerImageDraft: Identifiable {
    let id = UUID()
    let image: UIImage
}
