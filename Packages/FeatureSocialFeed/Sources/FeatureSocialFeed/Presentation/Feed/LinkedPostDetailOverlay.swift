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
    /// `animated` slides the overlay off with the insertion transition.
    /// Interactive swipe already moved the page — pass `false` so a second copy is not created.
    let onDismiss: (_ animated: Bool) -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isFinishingDismiss = false
    @StateObject private var videoCoordinator = FeedVideoPlaybackCoordinator()

    public init(
        presentation: PendingFeedPostNavigation,
        feedViewModel: FeedViewModel,
        fetchFriendsUseCase: FetchFriendsUseCaseProtocol? = nil,
        profileDependencies: FriendUserProfileDependencies? = nil,
        makeGifPickerViewModel: GifPickerViewModelFactory? = nil,
        uploadCommentImage: CommentImageUploadHandler? = nil,
        onDismiss: @escaping (_ animated: Bool) -> Void
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
                    expandBillSplit: presentation.expandBillSplit,
                    commentId: presentation.commentId
                ),
                feedViewModel: feedViewModel,
                fetchFriendsUseCase: fetchFriendsUseCase,
                profileDependencies: profileDependencies,
                makeGifPickerViewModel: makeGifPickerViewModel,
                onClose: dismissFromBackControl
            )
            .environment(\.feedVideoCoordinator, videoCoordinator)
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
            .splickFastPageSlide()
            .background {
                LinkedPostInteractiveDismissInstaller(
                    onChanged: handleInteractiveDragChanged,
                    onEnded: handleInteractiveDragEnded
                )
            }
        }
        .environment(\.commentImageUpload, uploadCommentImage)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SplickTheme.Colors.background.ignoresSafeArea(.container))
        .shadow(color: .black.opacity(0.14), radius: 16, x: -6, y: 0)
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

    private func handleInteractiveDragChanged(_ translation: CGFloat) {
        guard !isFinishingDismiss else { return }
        dragOffset = max(0, translation)
    }

    private func handleInteractiveDragEnded(translation: CGFloat, predicted: CGFloat, width: CGFloat) {
        guard !isFinishingDismiss else { return }
        let shouldDismiss = translation > 120 || predicted > 220
        if shouldDismiss {
            finishInteractiveDismiss(width: max(width, 1))
        } else {
            withAnimation(LinkedPostMotion.spring) {
                dragOffset = 0
            }
        }
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

// MARK: - Interactive dismiss (does not steal toolbar taps)

/// Attaches a leading-band pan to the overlay navigation controller.
/// Unlike a SwiftUI overlay, this does not sit above the back button.
private struct LinkedPostInteractiveDismissInstaller: UIViewControllerRepresentable {
    var onChanged: (CGFloat) -> Void
    var onEnded: (_ translation: CGFloat, _ predicted: CGFloat, _ width: CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChanged: onChanged, onEnded: onEnded)
    }

    func makeUIViewController(context: Context) -> LinkedPostInteractiveDismissHostController {
        let host = LinkedPostInteractiveDismissHostController()
        host.coordinator = context.coordinator
        return host
    }

    func updateUIViewController(
        _ uiViewController: LinkedPostInteractiveDismissHostController,
        context: Context
    ) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        uiViewController.installIfNeeded()
    }

    static func dismantleUIViewController(
        _ uiViewController: LinkedPostInteractiveDismissHostController,
        coordinator: Coordinator
    ) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChanged: (CGFloat) -> Void
        var onEnded: (_ translation: CGFloat, _ predicted: CGFloat, _ width: CGFloat) -> Void
        private var pan: UIPanGestureRecognizer?
        private weak var hostView: UIView?

        init(
            onChanged: @escaping (CGFloat) -> Void,
            onEnded: @escaping (CGFloat, CGFloat, CGFloat) -> Void
        ) {
            self.onChanged = onChanged
            self.onEnded = onEnded
        }

        func attach(to view: UIView) {
            hostView = view
            if pan == nil {
                let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
                gesture.name = "splick.linkedPost.interactiveDismiss"
                gesture.maximumNumberOfTouches = 1
                gesture.cancelsTouchesInView = false
                gesture.delegate = self
                pan = gesture
            }
            guard let pan else { return }
            if pan.view !== view {
                pan.view?.removeGestureRecognizer(pan)
                view.addGestureRecognizer(pan)
            }
        }

        func detach() {
            if let pan {
                pan.view?.removeGestureRecognizer(pan)
            }
            pan = nil
            hostView = nil
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }
            let translation = gesture.translation(in: view)
            switch gesture.state {
            case .changed:
                onChanged(translation.x)
            case .ended, .cancelled:
                let predicted = translation.x + gesture.velocity(in: view).x * 0.18
                onEnded(translation.x, predicted, view.bounds.width)
            default:
                break
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let view = hostView ?? gestureRecognizer.view else { return false }
            let point = touch.location(in: view)
            if point.y < view.safeAreaInsets.top + 44 {
                return false
            }
            let band = max(view.bounds.width * 0.25, 1)
            if view.effectiveUserInterfaceLayoutDirection == .rightToLeft {
                return point.x >= view.bounds.width - band
            }
            return point.x <= band
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
                  let view = pan.view else { return false }
            let translation = pan.translation(in: view)
            let rtl = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
            return SplickInteractivePopAxis.isOutwardHorizontalPop(
                translation: translation,
                isRightToLeft: rtl
            )
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            false
        }
    }
}

private final class LinkedPostInteractiveDismissHostController: UIViewController {
    var coordinator: LinkedPostInteractiveDismissInstaller.Coordinator?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        installIfNeeded()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent == nil {
            coordinator?.detach()
        } else {
            installIfNeeded()
        }
    }

    func installIfNeeded() {
        guard let coordinator else { return }
        if let nav = navigationController ?? ancestorNavigationController() {
            coordinator.attach(to: nav.view)
            return
        }
        for delay in [0.0, 0.05, 0.2] as [TimeInterval] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, let coordinator = self.coordinator else { return }
                if let nav = self.navigationController ?? self.ancestorNavigationController() {
                    coordinator.attach(to: nav.view)
                }
            }
        }
    }

    private func ancestorNavigationController() -> UINavigationController? {
        var responder: UIResponder? = view
        while let current = responder {
            if let nav = current as? UINavigationController {
                return nav
            }
            responder = current.next
        }
        return nil
    }
}
