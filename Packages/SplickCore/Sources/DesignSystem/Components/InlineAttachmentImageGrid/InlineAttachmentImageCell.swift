import SwiftUI
import Common

struct InlineAttachmentImageCell: View, Equatable {
    let image: InlineAttachmentPreviewImage
    let cornerRadius: CGFloat
    let showsMoreOverlay: Bool
    let moreCount: Int
    let onTap: () -> Void
    let onRemove: (() -> Void)?
    let onRetry: (() -> Void)?

    static func == (lhs: InlineAttachmentImageCell, rhs: InlineAttachmentImageCell) -> Bool {
        lhs.image == rhs.image
            && lhs.cornerRadius == rhs.cornerRadius
            && lhs.showsMoreOverlay == rhs.showsMoreOverlay
            && lhs.moreCount == rhs.moreCount
    }

    private var isFailed: Bool {
        if case .failed = image.uploadStatus { return true }
        return false
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                imageContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                InlineAttachmentUploadOverlay(
                    uploadStatus: image.uploadStatus,
                    onRetry: nil
                )

                if showsMoreOverlay, moreCount > 0 {
                    InlineAttachmentMoreImagesOverlay(hiddenCount: moreCount)
                }

                if isFailed, let onRetry {
                    failedRetryOverlay(onRetry: onRetry)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onTapGesture(perform: onTap)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(image.accessibilityLabel)

            if let onRemove, !isFailed {
                removeButton(action: onRemove)
            }
        }
    }

    @ViewBuilder
    private var imageContent: some View {
        if let preview = image.localPreview {
            Image(uiImage: preview.normalizedOrientation())
                .resizable()
                .scaledToFill()
        } else if let remoteURL = image.remoteURL {
            Color.clear
                .overlay {
                    RemoteImage(
                        url: remoteURL,
                        maxPixelSize: RemoteImageMetrics.inlineAttachmentMaxPixelWidth(pointWidth: 320)
                    ) { phase in
                        switch phase {
                        case .success(let loadedImage):
                            loadedImage
                                .resizable()
                                .scaledToFill()
                        default:
                            Rectangle()
                                .fill(SplickTheme.Colors.tertiaryBackground)
                                .overlay { SplickSpinner(size: .small) }
                        }
                    }
                }
                .clipped()
        } else {
            Rectangle()
                .fill(SplickTheme.Colors.tertiaryBackground)
        }
    }

    private func failedRetryOverlay(onRetry: @escaping () -> Void) -> some View {
        ZStack {
            Color.black.opacity(0.45)
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(SplickTheme.Colors.error)
                Button(action: onRetry) {
                    Text("Thử lại")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.22)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Thử tải lại ảnh")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tải ảnh thất bại")
    }

    private func removeButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.white, .black.opacity(0.45))
        }
        .buttonStyle(.plain)
        .padding(4)
        .accessibilityLabel("Xóa ảnh")
    }
}
