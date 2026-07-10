import SwiftUI
import DesignSystem

struct CommentAttachmentImageGrid: View {
    let images: [CommentAttachmentPreviewImage]
    var maxWidth: CGFloat
    var spacing: CGFloat = CommentAttachmentImageLayoutEngine.defaultSpacing
    var cornerRadius: CGFloat = SplickTheme.CornerRadius.medium
    let onTapImage: (Int) -> Void
    var onRemoveImage: ((Int) -> Void)?
    var onRetryImage: ((Int) -> Void)?

    private var layout: CommentAttachmentImageLayoutEngine.Layout {
        CommentAttachmentImageLayoutEngine.layout(imageCount: images.count)
    }

    private var gridHeight: CGFloat {
        layout.height(forWidth: maxWidth, spacing: spacing)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(layout.rows) { row in
                rowView(row)
            }
        }
        .frame(width: maxWidth, height: gridHeight, alignment: .leading)
        .animation(.easeOut(duration: 0.18), value: images.map(\.id))
    }

    @ViewBuilder
    private func rowView(_ row: CommentAttachmentImageLayoutEngine.Row) -> some View {
        let rowHeight = layout.rowHeight(for: row, width: maxWidth, spacing: spacing)

        HStack(spacing: spacing) {
            ForEach(row.slots) { slot in
                if images.indices.contains(slot.imageIndex) {
                    let image = images[slot.imageIndex]
                    let cellWidth = layout.cellWidth(for: slot, in: row, width: maxWidth, spacing: spacing)

                    EquatableView(
                        content: CommentAttachmentImageCell(
                            image: image,
                            cornerRadius: cornerRadius,
                            showsMoreOverlay: slot.moreOverlayCount != nil,
                            moreCount: slot.moreOverlayCount ?? 0,
                            onTap: { onTapImage(slot.imageIndex) },
                            onRemove: onRemoveImage.map { remove in { remove(slot.imageIndex) } },
                            onRetry: onRetryImage.map { retry in { retry(slot.imageIndex) } }
                        )
                    )
                    .frame(width: cellWidth, height: rowHeight)
                }
            }
        }
        .frame(width: maxWidth, height: rowHeight, alignment: .leading)
    }
}
