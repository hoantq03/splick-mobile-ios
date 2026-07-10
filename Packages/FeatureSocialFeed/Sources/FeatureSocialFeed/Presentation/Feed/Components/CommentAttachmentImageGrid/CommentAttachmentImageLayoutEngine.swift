import CoreGraphics

enum CommentAttachmentImageLayoutEngine {
    static let maxVisibleImages = 5
    static let defaultSpacing: CGFloat = 4

    struct Slot: Identifiable, Equatable {
        let imageIndex: Int
        let flex: CGFloat
        let aspectRatio: CGFloat
        let moreOverlayCount: Int?

        var id: Int { imageIndex }
    }

    struct Row: Identifiable, Equatable {
        let id: Int
        let slots: [Slot]
    }

    struct Layout: Equatable {
        let rows: [Row]
        let totalImageCount: Int

        func height(forWidth width: CGFloat, spacing: CGFloat = defaultSpacing) -> CGFloat {
            guard !rows.isEmpty else { return 0 }

            let rowHeights = rows.map { rowHeight(for: $0, width: width, spacing: spacing) }
            let spacingTotal = spacing * CGFloat(max(0, rows.count - 1))
            return rowHeights.reduce(0, +) + spacingTotal
        }

        func rowHeight(for row: Row, width: CGFloat, spacing: CGFloat = defaultSpacing) -> CGFloat {
            let slotCount = row.slots.count
            guard slotCount > 0 else { return 0 }

            let totalFlex = row.slots.reduce(0) { $0 + $1.flex }
            let horizontalSpacing = spacing * CGFloat(max(0, slotCount - 1))
            let availableWidth = width - horizontalSpacing

            return row.slots.map { slot in
                let cellWidth = availableWidth * (slot.flex / totalFlex)
                return cellWidth / max(slot.aspectRatio, 0.01)
            }.max() ?? 0
        }

        func cellWidth(
            for slot: Slot,
            in row: Row,
            width: CGFloat,
            spacing: CGFloat = defaultSpacing
        ) -> CGFloat {
            let slotCount = row.slots.count
            guard slotCount > 0 else { return 0 }

            let totalFlex = row.slots.reduce(0) { $0 + $1.flex }
            let horizontalSpacing = spacing * CGFloat(max(0, slotCount - 1))
            let availableWidth = width - horizontalSpacing
            return availableWidth * (slot.flex / totalFlex)
        }
    }

    static func layout(imageCount: Int) -> Layout {
        guard imageCount > 0 else {
            return Layout(rows: [], totalImageCount: 0)
        }

        let visibleCount = min(imageCount, maxVisibleImages)
        let extraCount = imageCount > maxVisibleImages ? imageCount - maxVisibleImages : nil

        switch visibleCount {
        case 1:
            return Layout(
                rows: [
                    Row(id: 0, slots: [slot(0, flex: 1, aspectRatio: 1.5)])
                ],
                totalImageCount: imageCount
            )
        case 2:
            return Layout(
                rows: [
                    Row(id: 0, slots: [slot(0), slot(1)])
                ],
                totalImageCount: imageCount
            )
        case 3:
            return Layout(
                rows: [
                    Row(id: 0, slots: [slot(0, flex: 1, aspectRatio: 2)]),
                    Row(id: 1, slots: [slot(1), slot(2)])
                ],
                totalImageCount: imageCount
            )
        case 4:
            return Layout(
                rows: [
                    Row(id: 0, slots: [slot(0), slot(1)]),
                    Row(id: 1, slots: [slot(2), slot(3)])
                ],
                totalImageCount: imageCount
            )
        default:
            return Layout(
                rows: [
                    Row(id: 0, slots: [slot(0, flex: 1, aspectRatio: 2)]),
                    Row(id: 1, slots: [slot(1), slot(2)]),
                    Row(id: 2, slots: [slot(3), slot(4, moreOverlayCount: extraCount)])
                ],
                totalImageCount: imageCount
            )
        }
    }

    private static func slot(
        _ imageIndex: Int,
        flex: CGFloat = 1,
        aspectRatio: CGFloat = 1,
        moreOverlayCount: Int? = nil
    ) -> Slot {
        Slot(
            imageIndex: imageIndex,
            flex: flex,
            aspectRatio: aspectRatio,
            moreOverlayCount: moreOverlayCount
        )
    }
}
