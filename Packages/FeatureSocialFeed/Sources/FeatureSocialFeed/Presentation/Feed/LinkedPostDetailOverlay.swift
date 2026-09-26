import SwiftUI
import UIKit
import DesignSystem
import Localization
import SplickDomain
import FeatureFriends
import FeatureStickers

public enum LinkedPostMotion {
    public static let spring = SplickPageSlideMotion.animation
}

/// Full-screen post detail presented from Expenses / deep links.
///
/// Presented via `fullScreenCover` (not a MainTab overlay) so sibling tab-bar /
/// camera / pager layers cannot swallow hits. No UIKit pan is installed on the
/// navigation controller — that previously cancelled every button tap.
public struct LinkedPostDetailOverlay: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.tabBarScrollState) private var tabBarScrollState

    let presentation: PendingFeedPostNavigation
    @ObservedObject var feedViewModel: FeedViewModel
    let fetchFriendsUseCase: FetchFriendsUseCaseProtocol?
    let fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol?
    let fetchGroupMembersUseCase: FetchGroupMembersUseCaseProtocol?
    let profileDependencies: FriendUserProfileDependencies?
    let makeGifPickerViewModel: GifPickerViewModelFactory?
    let uploadCommentImage: CommentImageUploadHandler?
    /// `animated` is kept for call-site compatibility; cover dismissal is driven by clearing the item.
    let onDismiss: (_ animated: Bool) -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isFinishingDismiss = false
    @StateObject private var videoCoordinator = FeedVideoPlaybackCoordinator()

    public init(
        presentation: PendingFeedPostNavigation,
        feedViewModel: FeedViewModel,
        fetchFriendsUseCase: FetchFriendsUseCaseProtocol? = nil,
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol? = nil,
        fetchGroupMembersUseCase: FetchGroupMembersUseCaseProtocol? = nil,
        profileDependencies: FriendUserProfileDependencies? = nil,
        makeGifPickerViewModel: GifPickerViewModelFactory? = nil,
        uploadCommentImage: CommentImageUploadHandler? = nil,
        onDismiss: @escaping (_ animated: Bool) -> Void
    ) {
        self.presentation = presentation
        self.feedViewModel = feedViewModel
        self.fetchFriendsUseCase = fetchFriendsUseCase
        self.fetchMyGroupsUseCase = fetchMyGroupsUseCase
        self.fetchGroupMembersUseCase = fetchGroupMembersUseCase
        self.profileDependencies = profileDependencies
        self.makeGifPickerViewModel = makeGifPickerViewModel
        self.uploadCommentImage = uploadCommentImage
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            PostDetailContainerView(
                destination: FeedPostDestination(
                    postId: presentation.postId,
                    mediaIndex: 0,
                    expandBillSplit: presentation.expandBillSplit,
                    commentId: presentation.commentId,
                    scrollToPendingEvidence: presentation.scrollToPendingEvidence
                ),
                feedViewModel: feedViewModel,
                fetchFriendsUseCase: fetchFriendsUseCase,
                fetchMyGroupsUseCase: fetchMyGroupsUseCase,
                fetchGroupMembersUseCase: fetchGroupMembersUseCase,
                profileDependencies: profileDependencies,
                makeGifPickerViewModel: makeGifPickerViewModel,
                onClose: dismissFromBackControl
            )
            .environment(\.feedVideoCoordinator, videoCoordinator)
            .environment(\.isLinkedPostPresentation, true)
            .navigationBarBackButtonHidden(true)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: dismissFromBackControl) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(SplickTheme.Colors.textPrimary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(languageService.text(.commonBack))
                }
            }
            // Leading-edge swipe-to-dismiss only — never covers the content hit target.
            .overlay(alignment: .leading) {
                leadingEdgeDismissHandle
            }
        }
        .environment(\.commentImageUpload, uploadCommentImage)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Opaque hit surface — transparent holes must not fall through to tabs underneath.
        .background(SplickTheme.Colors.background.ignoresSafeArea())
        .contentShape(Rectangle())
        .offset(x: max(0, dragOffset))
        .onAppear {
            Task { @MainActor in
                tabBarScrollState?.hide(flushToBottom: true)
            }
        }
        .onDisappear {
            Task { @MainActor in
                tabBarScrollState?.show()
            }
        }
    }

    /// Narrow strip so vertical scroll / buttons elsewhere stay fully interactive.
    private var leadingEdgeDismissHandle: some View {
        Color.clear
            .frame(width: 22)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .padding(.top, 56)
            .gesture(
                DragGesture(minimumDistance: 12, coordinateSpace: .local)
                    .onChanged { value in
                        guard !isFinishingDismiss else { return }
                        let dx = value.translation.width
                        let dy = abs(value.translation.height)
                        guard dx > 0, dx > dy else { return }
                        dragOffset = dx
                    }
                    .onEnded { value in
                        guard !isFinishingDismiss else { return }
                        let dx = value.translation.width
                        let predicted = dx + value.predictedEndTranslation.width * 0.35
                        let width = UIScreen.main.bounds.width
                        if dx > 120 || predicted > 220 {
                            finishInteractiveDismiss(width: max(width, 1))
                        } else {
                            withAnimation(LinkedPostMotion.spring) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            .accessibilityHidden(true)
    }

    private func finishInteractiveDismiss(width: CGFloat) {
        isFinishingDismiss = true
        withAnimation(LinkedPostMotion.spring) {
            dragOffset = width
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + SplickPageSlideMotion.duration) {
            onDismiss(false)
        }
    }

    private func dismissFromBackControl() {
        guard !isFinishingDismiss else { return }
        isFinishingDismiss = true
        onDismiss(true)
    }
}
