import SwiftUI
import AVKit
import UIKit
import SplickDomain

// MARK: - SwiftUI entry

struct MediaViewerView: View {
    let items: [PostMediaItem]
    let initialIndex: Int
    @Binding var isPresented: Bool

    var body: some View {
        MediaViewerContainer(
            items: items,
            initialIndex: initialIndex,
            onDismiss: { isPresented = false }
        )
        .ignoresSafeArea()
        .statusBarHidden(true)
    }
}

// MARK: - Presentation route (avoids fullScreenCover reading stale index)

struct MediaViewerRoute: Identifiable {
    let id = UUID()
    let index: Int
}

// MARK: - UIKit page controller (reliable horizontal paging + zoom + vertical dismiss)

private struct MediaViewerContainer: UIViewControllerRepresentable {
    let items: [PostMediaItem]
    let initialIndex: Int
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> MediaViewerViewController {
        let controller = MediaViewerViewController(items: items, initialIndex: initialIndex)
        controller.onDismiss = onDismiss
        controller.onPageChanged = { index in
            context.coordinator.currentIndex = index
        }
        context.coordinator.currentIndex = initialIndex
        return controller
    }

    func updateUIViewController(_ uiViewController: MediaViewerViewController, context: Context) {
        uiViewController.onDismiss = onDismiss
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var currentIndex: Int = 0
    }
}

// MARK: - MediaViewerViewController

private final class MediaViewerViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    private let items: [PostMediaItem]
    private var pages: [MediaPageViewController] = []
    private var currentIndex: Int
    private let pageIndicator = UILabel()
    private let closeButton = UIButton(type: .system)
    private var dismissPan: UIPanGestureRecognizer!
    private var dismissOffset: CGFloat = 0

    var onDismiss: (() -> Void)?
    var onPageChanged: ((Int) -> Void)?

    init(items: [PostMediaItem], initialIndex: Int) {
        self.items = items
        self.currentIndex = min(max(initialIndex, 0), max(items.count - 1, 0))
        super.init(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        dataSource = self
        delegate = self

        pages = items.enumerated().map { index, item in
            let page = MediaPageViewController(item: item)
            page.pageIndex = index
            page.onVerticalDismissChanged = { [weak self] offset in
                self?.applyDismissOffset(offset)
            }
            page.onVerticalDismissEnded = { [weak self] offset in
                self?.finishDismissDrag(offset)
            }
            return page
        }

        if let start = pageController(at: currentIndex) {
            setViewControllers([start], direction: .forward, animated: false)
        }

        setupChrome()
        setupDismissGesture()
        updatePageIndicator()
    }

    private func setupChrome() {
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        closeButton.layer.cornerRadius = 17
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        pageIndicator.font = .systemFont(ofSize: 13, weight: .medium)
        pageIndicator.textColor = .white
        pageIndicator.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        pageIndicator.layer.cornerRadius = 12
        pageIndicator.clipsToBounds = true
        pageIndicator.textAlignment = .center
        pageIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageIndicator)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 34),
            closeButton.heightAnchor.constraint(equalToConstant: 34),

            pageIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageIndicator.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            pageIndicator.heightAnchor.constraint(equalToConstant: 28),
            pageIndicator.widthAnchor.constraint(greaterThanOrEqualToConstant: 56)
        ])
    }

    private func setupDismissGesture() {
        dismissPan = UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:)))
        dismissPan.delegate = self
        view.addGestureRecognizer(dismissPan)
    }

    @objc private func closeTapped() {
        onDismiss?()
    }

    @objc private func handleDismissPan(_ recognizer: UIPanGestureRecognizer) {
        guard let current = viewControllers?.first as? MediaPageViewController,
              !current.isZoomed else { return }

        let translation = recognizer.translation(in: view)
        let velocity = recognizer.velocity(in: view)

        switch recognizer.state {
        case .changed:
            guard translation.y > 0, abs(translation.y) > abs(translation.x) else { return }
            applyDismissOffset(translation.y)
        case .ended, .cancelled:
            let shouldDismiss = translation.y > 120 && abs(translation.y) > abs(translation.x)
                || velocity.y > 900
            if shouldDismiss {
                onDismiss?()
            } else {
                UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.4) {
                    self.applyDismissOffset(0)
                }
            }
        default:
            break
        }
    }

    private func applyDismissOffset(_ offset: CGFloat) {
        dismissOffset = max(0, offset)
        let progress = min(1, dismissOffset / 280)
        view.backgroundColor = UIColor.black.withAlphaComponent(1 - progress * 0.85)
        for child in pages {
            child.view.transform = CGAffineTransform(translationX: 0, y: dismissOffset)
        }
        closeButton.transform = CGAffineTransform(translationX: 0, y: dismissOffset)
        pageIndicator.transform = CGAffineTransform(translationX: 0, y: dismissOffset)
    }

    private func finishDismissDrag(_ offset: CGFloat) {
        if offset > 100 {
            onDismiss?()
        } else {
            UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.4) {
                self.applyDismissOffset(0)
            }
        }
    }

    private func updatePageIndicator() {
        if items.count > 1 {
            pageIndicator.isHidden = false
            pageIndicator.text = "  \(currentIndex + 1) / \(items.count)  "
        } else {
            pageIndicator.isHidden = true
        }
    }

    private func pageController(at index: Int) -> MediaPageViewController? {
        guard pages.indices.contains(index) else { return nil }
        return pages[index]
    }

    // MARK: UIPageViewControllerDataSource

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard let page = viewController as? MediaPageViewController else { return nil }
        return pageController(at: page.pageIndex - 1)
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard let page = viewController as? MediaPageViewController else { return nil }
        return pageController(at: page.pageIndex + 1)
    }

    // MARK: UIPageViewControllerDelegate

    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed,
              let page = viewControllers?.first as? MediaPageViewController else { return }
        currentIndex = page.pageIndex
        onPageChanged?(currentIndex)
        updatePageIndicator()
        applyDismissOffset(0)
    }
}

extension MediaViewerViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === dismissPan,
              let page = viewControllers?.first as? MediaPageViewController else { return true }
        guard !page.isZoomed else { return false }
        let velocity = dismissPan.velocity(in: view)
        return abs(velocity.y) >= abs(velocity.x)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        false
    }
}

// MARK: - Single page (image zoom or video)

private final class MediaPageViewController: UIViewController, UIScrollViewDelegate {
    let item: PostMediaItem
    var pageIndex: Int = 0
    var onVerticalDismissChanged: ((CGFloat) -> Void)?
    var onVerticalDismissEnded: ((CGFloat) -> Void)?

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private var videoController: AVPlayerViewController?
    private var verticalDismissPan: UIPanGestureRecognizer!

    var isZoomed: Bool { scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 }

    init(item: PostMediaItem) {
        self.item = item
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let image = imageView.image {
            layoutImage(image)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        switch item.mediaType {
        case .image:
            setupImagePage()
        case .video:
            setupVideoPage()
        }
    }

    private func setupImagePage() {
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let url = item.mediaURL
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) else { return }
            imageView.image = image
            layoutImage(image)
        }

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        verticalDismissPan = UIPanGestureRecognizer(target: self, action: #selector(handleVerticalDismiss(_:)))
        verticalDismissPan.delegate = self
        view.addGestureRecognizer(verticalDismissPan)
    }

    private func setupVideoPage() {
        let player = AVPlayer(url: item.mediaURL)
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        playerVC.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(playerVC)
        view.addSubview(playerVC.view)
        playerVC.didMove(toParent: self)
        videoController = playerVC

        NSLayoutConstraint.activate([
            playerVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            playerVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        verticalDismissPan = UIPanGestureRecognizer(target: self, action: #selector(handleVerticalDismiss(_:)))
        verticalDismissPan.delegate = self
        view.addGestureRecognizer(verticalDismissPan)
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        if isZoomed {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            let point = recognizer.location(in: imageView)
            let zoomRect = zoomRect(for: scrollView.maximumZoomScale / 2, center: point)
            scrollView.zoom(to: zoomRect, animated: true)
        }
    }

    private func zoomRect(for scale: CGFloat, center: CGPoint) -> CGRect {
        let size = scrollView.bounds.size
        let width = size.width / scale
        let height = size.height / scale
        let origin = CGPoint(x: center.x - width / 2, y: center.y - height / 2)
        return CGRect(origin: origin, size: CGSize(width: width, height: height))
    }

    @objc private func handleVerticalDismiss(_ recognizer: UIPanGestureRecognizer) {
        guard !isZoomed else { return }
        let translation = recognizer.translation(in: view)
        let velocity = recognizer.velocity(in: view)

        switch recognizer.state {
        case .changed:
            guard translation.y > 0, abs(translation.y) > abs(translation.x) else { return }
            onVerticalDismissChanged?(translation.y)
        case .ended, .cancelled:
            let offset = translation.y > 0 && abs(translation.y) > abs(translation.x) ? translation.y : 0
            onVerticalDismissEnded?(offset > 0 ? offset : (velocity.y > 800 ? 120 : 0))
        default:
            break
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        item.mediaType == .image ? imageView : nil
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
    }

    private func layoutImage(_ image: UIImage) {
        let bounds = scrollView.bounds.size
        guard bounds.width > 0, bounds.height > 0 else { return }
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        imageView.frame = CGRect(x: 0, y: 0, width: width, height: height)
        scrollView.contentSize = imageView.frame.size
        centerImage()
    }

    private func centerImage() {
        let boundsSize = scrollView.bounds.size
        var frame = imageView.frame
        frame.origin.x = frame.width < boundsSize.width ? (boundsSize.width - frame.width) / 2 : 0
        frame.origin.y = frame.height < boundsSize.height ? (boundsSize.height - frame.height) / 2 : 0
        imageView.frame = frame
    }
}

extension MediaPageViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === verticalDismissPan, !isZoomed else { return false }
        let velocity = verticalDismissPan.velocity(in: view)
        return abs(velocity.y) >= abs(velocity.x)
    }
}
