import SwiftUI
import Common
import DesignSystem
import FeatureMedia
import Localization
import SplickDomain

public struct CustomEmojiComposerSheet: View {
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var emojiStore: CustomEmojiStore

    private let sourceImage: UIImage
    private let currentUserId: UUID?
    private let uploadMediaUseCase: UploadMediaUseCaseProtocol
    private let addEmojiUseCase: AddUserCustomEmojiUseCaseProtocol
    private let onUploaded: ((CustomEmoji) -> Void)?

    @State private var alias = ""

    public init(
        sourceImage: UIImage,
        currentUserId: UUID? = nil,
        uploadMediaUseCase: UploadMediaUseCaseProtocol,
        addEmojiUseCase: AddUserCustomEmojiUseCaseProtocol,
        onUploaded: ((CustomEmoji) -> Void)? = nil
    ) {
        self.sourceImage = sourceImage
        self.currentUserId = currentUserId
        self.uploadMediaUseCase = uploadMediaUseCase
        self.addEmojiUseCase = addEmojiUseCase
        self.onUploaded = onUploaded
    }

    public var body: some View {
        ImageCropSheet(
            title: languageService.text(.stickersAddEmojiTitle),
            emptyHint: languageService.text(.messagingGroupAvatarAlignHint),
            alignHint: languageService.text(.messagingGroupAvatarAlignHint),
            changePhotoTitle: languageService.text(.messagingGroupChangePhoto),
            loadErrorText: languageService.text(.stickersOpenImageFailed),
            saveTitle: languageService.text(.stickersUpload),
            initialImage: ImageCropRenderer.downsampled(sourceImage),
            outputSize: ImageCropRenderer.emojiOutputSize,
            onSave: upload(cropped:)
        ) {
            TextField(languageService.text(.feedCustomEmojiShortcodePlaceholder), text: $alias)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(SplickTheme.Spacing.sm)
                .background {
                    RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous)
                        .fill(SplickTheme.Colors.tertiaryBackground)
                }
        }
        .environmentObject(languageService)
    }

    private func upload(cropped: UIImage) async throws {
        let resolvedAlias = normalizeAlias(alias)
        if !resolvedAlias.isEmpty {
            guard CustomEmojiShortcodeValidator.isValid(resolvedAlias) else {
                throw CustomEmojiError.invalidShortcode
            }
        }

        let (data, mimeType) = try CustomEmojiImageProcessor.prepareUploadData(from: cropped)
        let upload = try await uploadMediaUseCase.execute(
            imageData: data,
            mimeType: mimeType,
            purpose: MediaUploadPurpose.userCustomEmoji,
            groupId: nil
        )
        let uploaded = try await addEmojiUseCase.execute(
            alias: resolvedAlias.isEmpty ? nil : resolvedAlias,
            mediaId: upload.id
        )
        let emoji = CustomEmoji(
            id: uploaded.id,
            ownerId: uploaded.ownerId ?? currentUserId,
            shortcode: uploaded.shortcode,
            mediaUrl: uploaded.mediaUrl,
            createdAt: uploaded.createdAt
        )
        emojiStore.upsert(emoji)
        onUploaded?(emoji)
    }

    private func normalizeAlias(_ rawValue: String) -> String {
        let folded = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: ":", with: "")

        var normalized = ""
        var previousWasSeparator = false
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                normalized.unicodeScalars.append(scalar)
                previousWasSeparator = false
            } else if !normalized.isEmpty, !previousWasSeparator {
                normalized.append("_")
                previousWasSeparator = true
            }
        }
        return normalized.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }
}
