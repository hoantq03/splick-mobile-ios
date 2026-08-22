import SwiftUI
import Common
import DesignSystem
import FeatureMedia
import Localization
import SplickDomain

public struct CustomEmojiComposerSheet: View {
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var emojiStore: CustomEmojiStore
    @Environment(\.dismiss) private var dismiss

    private let sourceImage: UIImage
    private let currentUserId: UUID?
    private let uploadMediaUseCase: UploadMediaUseCaseProtocol
    private let addEmojiUseCase: AddUserCustomEmojiUseCaseProtocol
    private let onUploaded: ((CustomEmoji) -> Void)?

    @State private var alias = ""
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var transform = CustomEmojiCropTransform()

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
        NavigationStack {
            VStack(spacing: SplickTheme.Spacing.md) {
                CustomEmojiCropEditor(
                    sourceImage: sourceImage,
                    transform: $transform
                )
                .padding(.horizontal, SplickTheme.Spacing.md)

                TextField(languageService.text(.feedCustomEmojiShortcodePlaceholder), text: $alias)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(SplickTheme.Spacing.sm)
                    .background {
                        RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous)
                            .fill(SplickTheme.Colors.tertiaryBackground)
                    }
                    .padding(.horizontal, SplickTheme.Spacing.md)

                Button {
                    Task { await upload() }
                } label: {
                    Group {
                        if isUploading {
                            ProgressView()
                        } else {
                            Text(languageService.text(.stickersUpload))
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background {
                    Capsule(style: .continuous)
                        .fill(SplickTheme.Colors.primaryGradientStart)
                }
                .disabled(isUploading || transform.crop.width < 2)
                .padding(.horizontal, SplickTheme.Spacing.md)

                Spacer(minLength: 0)
            }
            .padding(.top, SplickTheme.Spacing.sm)
            .padding(.bottom, SplickTheme.Spacing.md)
            .background(SplickTheme.Colors.background)
            .navigationTitle(languageService.text(.stickersAddEmojiTitle))
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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

    @MainActor
    private func upload() async {
        isUploading = true
        defer { isUploading = false }

        do {
            let resolvedAlias = normalizeAlias(alias)
            if !resolvedAlias.isEmpty {
                guard CustomEmojiShortcodeValidator.isValid(resolvedAlias) else {
                    throw CustomEmojiError.invalidShortcode
                }
            }

            let image = CustomEmojiCropRenderer.render(source: sourceImage, transform: transform)
            let (data, mimeType) = try CustomEmojiImageProcessor.prepareUploadData(from: image)
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
            dismiss()
        } catch {
            errorMessage = languageService.localizedMessage(for: error)
        }
    }
}
