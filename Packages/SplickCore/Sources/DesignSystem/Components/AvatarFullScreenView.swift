import SwiftUI
import UIKit

/// Full-screen avatar viewer: pinch-to-zoom, pan, double-tap zoom, swipe-down dismiss.
/// Uses UIKit (same pattern as the media viewer) so the close button sits below the
/// Dynamic Island and vertical dismiss is not stolen by SwiftUI/Nuke gestures.
public struct AvatarFullScreenView: View {
    public let url: URL?
    public let placeholderName: String
    public let onDismiss: () -> Void

    public init(
        url: URL?,
        placeholderName: String,
        onDismiss: @escaping () -> Void
    ) {
        self.url = url
        self.placeholderName = placeholderName
        self.onDismiss = onDismiss
    }

    public var body: some View {
        AvatarFullScreenContainer(
            url: url,
            placeholderName: placeholderName,
            onDismiss: onDismiss
        )
        .ignoresSafeArea()
        .statusBarHidden(true)
    }
}

private struct AvatarFullScreenContainer: UIViewControllerRepresentable {
    let url: URL?
    let placeholderName: String
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> AvatarFullScreenViewController {
        let controller = AvatarFullScreenViewController(
            url: url,
            placeholderName: placeholderName
        )
        controller.onDismiss = onDismiss
        return controller
    }

    func updateUIViewController(_ uiViewController: AvatarFullScreenViewController, context: Context) {
        uiViewController.onDismiss = onDismiss
    }
}

private final class AvatarFullScreenViewController: UIViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    var onDismiss: (() -> Void)?

    private let imageURL: URL?
    private let placeholderName: String

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let placeholderContainer = UIView()
    private let placeholderLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let closeButton = UIButton(type: .system)

    private var dismissPan: UIPanGestureRecognizer!
    private var dismissOffset: CGFloat = 0
    private var imageLoadHandle: RemoteUIImageLoadHandle?

    private var isZoomed: Bool {
        scrollView.zoomScale > scrollView.minimumZoomScale + 0.01
    }

    init(url: URL?, placeholderName: String) {
        self.imageURL = url
        self.placeholderName = placeholderName
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    deinit {
        imageLoadHandle?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupScrollView()
        setupPlaceholder()
        setupSpinner()
        setupCloseButton()
        setupDismissGesture()
        loadContent()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let image = imageView.image {
            layoutImage(image)
        }
    }

    private func setupScrollView() {
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.alwaysBounceVertical = false
        scrollView.backgroundColor = .clear
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.isHidden = true
        scrollView.addSubview(imageView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
    }

    private func setupPlaceholder() {
        placeholderContainer.translatesAutoresizingMaskIntoConstraints = false
        placeholderContainer.layer.cornerRadius = 90
        placeholderContainer.clipsToBounds = true
        placeholderContainer.isHidden = true
        view.insertSubview(placeholderContainer, belowSubview: scrollView)

        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor(red: 91 / 255, green: 108 / 255, blue: 1, alpha: 1).cgColor,
            UIColor(red: 78 / 255, green: 205 / 255, blue: 196 / 255, alpha: 1).cgColor,
            UIColor(red: 42 / 255, green: 157 / 255, blue: 143 / 255, alpha: 1).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.frame = CGRect(x: 0, y: 0, width: 180, height: 180)
        placeholderContainer.layer.insertSublayer(gradient, at: 0)

        placeholderLabel.text = String(placeholderName.prefix(2)).uppercased()
        placeholderLabel.font = .systemFont(ofSize: 56, weight: .bold)
        placeholderLabel.textColor = .white
        placeholderLabel.textAlignment = .center
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderContainer.addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            placeholderContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            placeholderContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            placeholderContainer.widthAnchor.constraint(equalToConstant: 180),
            placeholderContainer.heightAnchor.constraint(equalToConstant: 180),
            placeholderLabel.centerXAnchor.constraint(equalTo: placeholderContainer.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: placeholderContainer.centerYAnchor)
        ])
    }

    private func setupSpinner() {
        spinner.color = .white
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupCloseButton() {
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        closeButton.layer.cornerRadius = 22
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.accessibilityLabel = "Close"
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func setupDismissGesture() {
        dismissPan = UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:)))
        dismissPan.delegate = self
        view.addGestureRecognizer(dismissPan)
    }

    private func loadContent() {
        guard let imageURL else {
            showPlaceholder()
            return
        }

        spinner.startAnimating()
        let maxPixelSize = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height) * UIScreen.main.scale
        imageLoadHandle?.cancel()
        imageLoadHandle = RemoteUIImageLoader.load(url: imageURL, maxPixelSize: maxPixelSize) { [weak self] image in
            guard let self else { return }
            self.spinner.stopAnimating()
            guard let image else {
                self.showPlaceholder()
                return
            }
            self.imageView.image = image
            self.imageView.isHidden = false
            self.placeholderContainer.isHidden = true
            self.layoutImage(image)
        }
    }

    private func showPlaceholder() {
        spinner.stopAnimating()
        imageView.isHidden = true
        placeholderContainer.isHidden = false
    }

    @objc private func closeTapped() {
        onDismiss?()
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        guard !imageView.isHidden else { return }
        if isZoomed {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            let point = recognizer.location(in: imageView)
            let zoomRect = zoomRect(for: min(scrollView.maximumZoomScale, 2.5), center: point)
            scrollView.zoom(to: zoomRect, animated: true)
        }
    }

    @objc private func handleDismissPan(_ recognizer: UIPanGestureRecognizer) {
        guard !isZoomed else { return }

        let translation = recognizer.translation(in: view)
        let velocity = recognizer.velocity(in: view)

        switch recognizer.state {
        case .changed:
            guard translation.y > 0, abs(translation.y) > abs(translation.x) else { return }
            applyDismissOffset(translation.y)
        case .ended, .cancelled:
            let shouldDismiss = translation.y > 100 && abs(translation.y) > abs(translation.x)
                || velocity.y > 800
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
        let transform = CGAffineTransform(translationX: 0, y: dismissOffset)
        scrollView.transform = transform
        placeholderContainer.transform = transform
        closeButton.transform = transform
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView.isHidden ? nil : imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === dismissPan, !isZoomed else { return false }
        let velocity = dismissPan.velocity(in: view)
        return abs(velocity.y) >= abs(velocity.x)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        false
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
        scrollView.zoomScale = scrollView.minimumZoomScale
        centerImage()
    }

    private func centerImage() {
        let boundsSize = scrollView.bounds.size
        var frame = imageView.frame
        frame.origin.x = frame.width < boundsSize.width ? (boundsSize.width - frame.width) / 2 : 0
        frame.origin.y = frame.height < boundsSize.height ? (boundsSize.height - frame.height) / 2 : 0
        imageView.frame = frame
    }

    private func zoomRect(for scale: CGFloat, center: CGPoint) -> CGRect {
        let size = scrollView.bounds.size
        let width = size.width / scale
        let height = size.height / scale
        let origin = CGPoint(x: center.x - width / 2, y: center.y - height / 2)
        return CGRect(origin: origin, size: CGSize(width: width, height: height))
    }
}
