import SwiftUI
import DesignSystem
import Localization
import SplickDomain
import FeatureFriends
import FeatureStickers

public enum LinkedPostMotion {
    public static let spring = Animation.spring(response: 0.42, dampingFraction: 0.88, blendDuration: 0.1)
}

/// Full-screen post detail that slides in from the trailing edge (e.g. from Expenses).
public struct LinkedPostDetailOverlay: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.tabBarScrollState) private var tabBarScrollState

    let presentation: PendingFeedPostNavigation
    @ObservedObject var feedViewModel: FeedViewModel
    let fetchFriendsUseCase: FetchFriendsUseCaseProtocol?
    let profileDependencies: FriendUserProfileDependencies?
    let makeGifPickerViewModel: GifPickerViewModelFactory?
    let uploadCommentImage: CommentImageUploadHandler?
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

    public init(
        presentation: PendingFeedPostNavigation,
        feedViewModel: FeedViewModel,
        fetchFriendsUseCase: FetchFriendsUseCaseProtocol? = nil,
        profileDependencies: FriendUserProfileDependencies? = nil,
        makeGifPickerViewModel: GifPickerViewModelFactory? = nil,
        uploadCommentImage: CommentImageUploadHandler? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.feedViewModel = feedViewModel
        self.fetchFriendsUseCase = fetchFriendsUseCase
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
                    expandBillSplit: presentation.expandBillSplit
                ),
                feedViewModel: feedViewModel,
                fetchFriendsUseCase: fetchFriendsUseCase,
                profileDependencies: profileDependencies,
                makeGifPickerViewModel: makeGifPickerViewModel
            )
            .navigationBarBackButtonHidden(true)
            .toolbarBackground(SplickTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: dismiss) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(SplickTheme.Colors.textPrimary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                }
            }
        }
        .environment(\.commentImageUpload, uploadCommentImage)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SplickTheme.Colors.background.ignoresSafeArea())
        .shadow(color: .black.opacity(0.14), radius: 16, x: -6, y: 0)
        .offset(x: max(0, dragOffset))
        .gesture(interactiveDismissGesture)
        .onAppear {
            tabBarScrollState?.hide(flushToBottom: true)
        }
        .onDisappear {
            tabBarScrollState?.show()
        }
    }

    private var interactiveDismissGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                guard value.translation.width > 0 else {
                    dragOffset = 0
                    return
                }
                dragOffset = value.translation.width
            }
            .onEnded { value in
                let shouldDismiss = value.translation.width > 120
                    || value.predictedEndTranslation.width > 220
                if shouldDismiss {
                    dismiss()
                } else {
                    withAnimation(LinkedPostMotion.spring) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func dismiss() {
        withAnimation(LinkedPostMotion.spring) {
            dragOffset = 0
            onDismiss()
        }
    }
}
