import SwiftUI
import UIKit
import DesignSystem
import SplickDomain

struct LocalImagePreviewRoute: Identifiable {
    let id = UUID()
    let index: Int
}

enum LocalImagePreviewSupport {
    static func decodeImages(from attachments: [CommentSubmissionAttachment]) -> [UIImage] {
        attachments.compactMap { attachment in
            guard attachment.kind == .image, let data = attachment.data else { return nil }
            return UIImage(data: data)
        }
    }
}

struct LocalImageFullscreenPreview: View {
    let images: [UIImage]
    let initialIndex: Int
    let onDismiss: () -> Void

    @State private var selectedIndex: Int

    init(images: [UIImage], initialIndex: Int, onDismiss: @escaping () -> Void) {
        self.images = images
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        _selectedIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    ZoomableUIImageScrollView(image: image)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .always : .never))
            .ignoresSafeArea()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.black.opacity(0.55)))
            }
            .padding(.top, 8)
            .padding(.trailing, 16)
        }
        .statusBarHidden(true)
    }
}

struct LocalImageThumbnailStrip: View {
    let images: [UIImage]
    var thumbnailWidth: CGFloat = 72
    var thumbnailHeight: CGFloat = 72
    let onTapImage: (Int) -> Void
    let onRemoveImage: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topTrailing) {
                        Button {
                            onTapImage(index)
                        } label: {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: thumbnailWidth, height: thumbnailHeight)
                                .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))
                                .contentShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Xem ảnh")

                        Button {
                            onRemoveImage(index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white, .black.opacity(0.45))
                        }
                        .padding(4)
                    }
                }
            }
        }
    }
}

struct CommentAttachmentDraftStrip: View {
    let drafts: [CommentAttachmentDraft]
    var thumbnailWidth: CGFloat = 72
    var thumbnailHeight: CGFloat = 72
    let onTapDraft: (Int) -> Void
    let onRemoveDraft: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(drafts.enumerated()), id: \.element.id) { index, draft in
                    ZStack(alignment: .topTrailing) {
                        ZStack {
                            if draft.previewImage != nil || draft.kind == .gif {
                                Button {
                                    onTapDraft(index)
                                } label: {
                                    draftThumbnail(draft)
                                }
                                .buttonStyle(.plain)
                                .disabled(draft.phase != .ready)
                            } else {
                                loadingThumbnail
                            }

                            if draft.phase == .loading {
                                RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium)
                                    .fill(Color.black.opacity(0.28))
                                nativeUploadProgressIndicator(light: true)
                            }
                        }
                        .frame(width: thumbnailWidth, height: thumbnailHeight)
                        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))

                        if case .failed = draft.phase {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(SplickTheme.Colors.error)
                                .padding(4)
                        } else {
                            Button {
                                onRemoveDraft(index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.white, .black.opacity(0.45))
                            }
                            .padding(4)
                        }
                    }
                }
            }
        }
    }

    private var loadingThumbnail: some View {
        RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium)
            .fill(SplickTheme.Colors.tertiaryBackground)
            .overlay { nativeUploadProgressIndicator(light: false) }
    }

    @ViewBuilder
    private func nativeUploadProgressIndicator(light: Bool) -> some View {
        if light {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.regular)
                .tint(.white)
        } else {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.regular)
        }
    }

    @ViewBuilder
    private func draftThumbnail(_ draft: CommentAttachmentDraft) -> some View {
        switch draft.kind {
        case .image:
            if let image = draft.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                loadingThumbnail
            }
        case .gif:
            if let url = draft.submission?.remoteURL {
                AnimatedRemoteImage(
                    url: url,
                    contentMode: .fill,
                    maxPixelSize: RemoteImageMetrics.inlineAttachmentMaxPixelWidth(pointWidth: thumbnailWidth)
                )
            } else {
                loadingThumbnail
            }
        default:
            attachmentPlaceholder(icon: "paperclip")
        }
    }

    private func attachmentPlaceholder(icon: String) -> some View {
        RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium)
            .fill(SplickTheme.Colors.tertiaryBackground)
            .overlay {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
    }
}

struct PendingCommentAttachmentStrip: View {
    let attachments: [CommentSubmissionAttachment]
    var thumbnailWidth: CGFloat = 72
    var thumbnailHeight: CGFloat = 72
    let onTapAttachment: (Int) -> Void
    let onRemoveAttachment: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(attachments.enumerated()), id: \.offset) { index, attachment in
                    ZStack(alignment: .topTrailing) {
                        Button {
                            onTapAttachment(index)
                        } label: {
                            attachmentThumbnail(attachment)
                                .frame(width: thumbnailWidth, height: thumbnailHeight)
                                .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))
                                .contentShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(attachment.kind == .gif ? "Xem GIF" : "Xem ảnh")

                        Button {
                            onRemoveAttachment(index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white, .black.opacity(0.45))
                        }
                        .padding(4)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func attachmentThumbnail(_ attachment: CommentSubmissionAttachment) -> some View {
        switch attachment.kind {
        case .image:
            if let data = attachment.data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                attachmentPlaceholder(icon: "photo")
            }
        case .gif:
            if let url = attachment.remoteURL {
                AnimatedRemoteImage(
                    url: url,
                    contentMode: .fill,
                    maxPixelSize: RemoteImageMetrics.inlineAttachmentMaxPixelWidth(pointWidth: thumbnailWidth)
                )
            } else {
                attachmentPlaceholder(icon: "face.smiling")
            }
        default:
            attachmentPlaceholder(icon: "paperclip")
        }
    }

    private func attachmentPlaceholder(icon: String) -> some View {
        RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium)
            .fill(SplickTheme.Colors.tertiaryBackground)
            .overlay {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
    }
}

struct RemoteGifFullscreenPreview: View {
    let url: URL
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            AnimatedRemoteImage(url: url, contentMode: .fit, maxPixelSize: 2048)
                .ignoresSafeArea()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.black.opacity(0.55)))
            }
            .padding(.top, 8)
            .padding(.trailing, 16)
        }
        .statusBarHidden(true)
    }
}

struct ZoomableUIImageScrollView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .clear

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scrollView

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        DispatchQueue.main.async {
            context.coordinator.layoutImage()
        }

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
        context.coordinator.layoutImage()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage()
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView, let imageView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
                return
            }
            let point = recognizer.location(in: imageView)
            let zoomScale = scrollView.maximumZoomScale / 2
            let size = scrollView.bounds.size
            let width = size.width / zoomScale
            let height = size.height / zoomScale
            let origin = CGPoint(x: point.x - width / 2, y: point.y - height / 2)
            scrollView.zoom(
                to: CGRect(origin: origin, size: CGSize(width: width, height: height)),
                animated: true
            )
        }

        func layoutImage() {
            guard let scrollView, let imageView, let image = imageView.image else { return }
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
            guard let scrollView, let imageView else { return }
            let boundsSize = scrollView.bounds.size
            var frame = imageView.frame
            frame.origin.x = frame.width < boundsSize.width ? (boundsSize.width - frame.width) / 2 : 0
            frame.origin.y = frame.height < boundsSize.height ? (boundsSize.height - frame.height) / 2 : 0
            imageView.frame = frame
        }
    }
}
