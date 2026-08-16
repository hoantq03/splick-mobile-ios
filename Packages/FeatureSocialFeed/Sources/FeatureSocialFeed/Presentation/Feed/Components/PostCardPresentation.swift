import Foundation
import SwiftUI
import PhotosUI
import DesignSystem
import Localization
import SplickDomain
import FeatureStickers

/// Sheet / picker presentation requested by a post card — hosted once at list/detail level.
enum PostCardPresentation: Identifiable {
    case reactions(Post)
    case emojiPicker(Post)
    case viewers(Post)
    case share(Post)
    case customEmojiUpload
    case paymentEvidence(Post, splitId: UUID, attachments: [CommentSubmissionAttachment])
    case paymentEvidencePhotoPicker(Post)

    var id: String {
        switch self {
        case .reactions(let post): return "reactions-\(post.id)"
        case .emojiPicker(let post): return "emojiPicker-\(post.id)"
        case .viewers(let post): return "viewers-\(post.id)"
        case .share(let post): return "share-\(post.id)"
        case .customEmojiUpload: return "customEmojiUpload"
        case .paymentEvidence(let post, let splitId, _):
            return "paymentEvidence-\(post.id)-\(splitId)"
        case .paymentEvidencePhotoPicker(let post):
            return "paymentEvidencePicker-\(post.id)"
        }
    }

    var post: Post? {
        switch self {
        case .reactions(let post),
             .emojiPicker(let post),
             .viewers(let post),
             .share(let post),
             .paymentEvidence(let post, _, _),
             .paymentEvidencePhotoPicker(let post):
            return post
        case .customEmojiUpload:
            return nil
        }
    }
}

/// Stable action bag so `PostCardView` can compare without closure identity.
@MainActor
final class PostCardActions: ObservableObject {
    var onReact: (UUID, String) -> Void = { _, _ in }
    var onDelete: (UUID) -> Void = { _ in }
    var onUserTap: (UserSummary) -> Void = { _ in }
    var onOpenComments: (Post) -> Void = { _ in }
    var onShowCompanions: (Post) -> Void = { _ in }
    var onOpenDetail: ((Post, Int) -> Void)?
    var onMediaTap: ((Post, Int) -> Void)?
    var onPresent: (PostCardPresentation) -> Void = { _ in }
    var onSendBillReminder: (
        (UUID, [UUID]?, String, [CommentSubmissionAttachment]) async throws -> SendBillReminderResult
    )?
    var onSubmitPaymentEvidence: (
        (UUID, UUID, String?, [CommentSubmissionAttachment]) async throws -> Void
    )?
    var makeGifPickerViewModel: GifPickerViewModelFactory?
}

/// Hosts post-card sheets once for a feed list or detail screen.
struct PostCardPresentationHost: ViewModifier {
    @Binding var presentation: PostCardPresentation?
    let currentUser: UserSummary?
    let languageService: LanguageService
    let onUserTap: (UserSummary) -> Void
    let onReact: (UUID, String) -> Void
    let onSubmitPaymentEvidence: ((UUID, UUID, String?, [CommentSubmissionAttachment]) async throws -> Void)?
    let onFetchReactions: ((UUID) async throws -> [UserReactionSummary])?
    let customEmojiDependencies: CustomEmojiDependencies?
    @Binding var paymentEvidencePhotoPickerItems: [PhotosPickerItem]
    let onPaymentEvidencePhotosPicked: ([PhotosPickerItem]) async -> Void

    func body(content: Content) -> some View {
        content
            .sheet(item: $presentation) { item in
                sheetContent(for: item)
            }
            .photosPicker(
                isPresented: Binding(
                    get: {
                        if case .paymentEvidencePhotoPicker = presentation { return true }
                        return false
                    },
                    set: { presented in
                        if !presented, case .paymentEvidencePhotoPicker = presentation {
                            presentation = nil
                        }
                    }
                ),
                selection: $paymentEvidencePhotoPickerItems,
                maxSelectionCount: 3,
                matching: .images
            )
            .onChange(of: paymentEvidencePhotoPickerItems) { items in
                Task { await onPaymentEvidencePhotosPicked(items) }
            }
    }

    @ViewBuilder
    private func sheetContent(for item: PostCardPresentation) -> some View {
        switch item {
        case .reactions(let post):
            ReactionDetailSheet(
                post: post,
                load: onFetchReactions.map { fetch in
                    { try await fetch(post.id) }
                },
                onUserTap: { user in
                    presentation = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        onUserTap(user)
                    }
                }
            )
        case .emojiPicker(let post):
            EmojiPickerSheet(
                currentUserId: currentUser?.id,
                onPick: { emoji in
                    onReact(post.id, emoji)
                    presentation = nil
                },
                onOpenUpload: {
                    presentation = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        presentation = .customEmojiUpload
                    }
                }
            )
        case .viewers(let post):
            ViewersListSheet(
                viewers: post.viewers,
                onUserTap: { user in
                    presentation = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        onUserTap(user)
                    }
                }
            )
        case .share(let post):
            SharePostSheet(
                post: post,
                fallbackCaption: languageService.text(.feedShareFallbackCaption)
            )
        case .customEmojiUpload:
            if let deps = customEmojiDependencies {
                CustomEmojiUploadSheet(
                    currentUserId: currentUser?.id,
                    customEmojiFetcher: deps.fetcher,
                    uploadMediaUseCase: deps.uploadMediaUseCase,
                    addEmojiUseCase: deps.addEmojiUseCase,
                    deleteEmojiUseCase: deps.deleteEmojiUseCase
                )
            }
        case .paymentEvidence(let post, _, let attachments):
            PaymentEvidenceSheet(
                postAuthorName: post.author.displayName,
                initialAttachments: attachments
            ) { message, submissionAttachments in
                guard let split = post.billSplitLine(for: currentUser?.id ?? UUID()) else { return }
                try await onSubmitPaymentEvidence?(
                    post.id,
                    split.id,
                    message,
                    submissionAttachments
                )
            }
        case .paymentEvidencePhotoPicker:
            EmptyView()
        }
    }
}

extension View {
    func postCardPresentationHost(
        presentation: Binding<PostCardPresentation?>,
        currentUser: UserSummary?,
        languageService: LanguageService,
        onUserTap: @escaping (UserSummary) -> Void,
        onReact: @escaping (UUID, String) -> Void,
        onSubmitPaymentEvidence: (
            (UUID, UUID, String?, [CommentSubmissionAttachment]) async throws -> Void
        )?,
        onFetchReactions: ((UUID) async throws -> [UserReactionSummary])? = nil,
        customEmojiDependencies: CustomEmojiDependencies?,
        paymentEvidencePhotoPickerItems: Binding<[PhotosPickerItem]>,
        onPaymentEvidencePhotosPicked: @escaping ([PhotosPickerItem]) async -> Void
    ) -> some View {
        modifier(
            PostCardPresentationHost(
                presentation: presentation,
                currentUser: currentUser,
                languageService: languageService,
                onUserTap: onUserTap,
                onReact: onReact,
                onSubmitPaymentEvidence: onSubmitPaymentEvidence,
                onFetchReactions: onFetchReactions,
                customEmojiDependencies: customEmojiDependencies,
                paymentEvidencePhotoPickerItems: paymentEvidencePhotoPickerItems,
                onPaymentEvidencePhotosPicked: onPaymentEvidencePhotosPicked
            )
        )
    }
}
