import SwiftUI
import DesignSystem

enum CommentThreadLayout {
    /// Gutter column width (lines draw only here).
    static let connectorWidth: CGFloat = 14
    /// Indent so reply avatars align with parent text column (avatar 28 + spacing 8).
    static let replyIndent: CGFloat = 36
    static var replyBlockLeading: CGFloat { replyIndent - connectorWidth }

    static let lineWidth: CGFloat = 2
    static let cornerRadius: CGFloat = 8
    /// Gap between the bottom of the parent avatar and where the trunk line begins.
    static let gapBelowAvatar: CGFloat = 2
}

// MARK: - Metrics
// All positions are measured in the parent CommentBranchView's named coordinate space.
// Using named spaces (not .global) keeps values stable during ScrollView scrolling.

struct CommentThreadMetrics: Equatable {
    /// Y where the trunk starts, in the parent branch's named space.
    var threadStartY: CGFloat?
    /// Centers of direct-child reply avatars, in the parent branch's named space.
    var avatarCenters: [UUID: CGPoint] = [:]
}

struct CommentThreadMetricsKey: PreferenceKey {
    static var defaultValue: [UUID: CommentThreadMetrics] { [:] }

    static func reduce(
        value: inout [UUID: CommentThreadMetrics],
        nextValue: () -> [UUID: CommentThreadMetrics]
    ) {
        for (groupId, metrics) in nextValue() {
            var merged = value[groupId] ?? CommentThreadMetrics()
            if let y = metrics.threadStartY { merged.threadStartY = y }
            merged.avatarCenters.merge(metrics.avatarCenters) { _, new in new }
            value[groupId] = merged
        }
    }
}

// MARK: - Shape

struct CommentThreadLinesShape: Shape {
    let startY: CGFloat
    let avatarCentersY: [CGFloat]
    /// X of the vertical trunk, in the overlay's coordinate space.
    let trunkX: CGFloat
    /// X where the L-hook ends (right of connector column), in overlay space.
    let hookEndX: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !avatarCentersY.isEmpty else { return path }

        path.move(to: CGPoint(x: trunkX, y: startY))

        for (index, avatarY) in avatarCentersY.enumerated() {
            let bendY = max(startY, avatarY - CommentThreadLayout.cornerRadius)

            path.addLine(to: CGPoint(x: trunkX, y: bendY))
            path.addQuadCurve(
                to: CGPoint(x: hookEndX, y: avatarY),
                control: CGPoint(x: trunkX, y: avatarY)
            )

            if index < avatarCentersY.count - 1 {
                path.move(to: CGPoint(x: trunkX, y: avatarY))
            }
        }

        return path
    }
}

// MARK: - Anchor roles

enum CommentThreadAnchorRole {
    case threadStart
    case avatarCenter
}

// MARK: - Reporting helpers

extension View {
    /// Reports a layout anchor into the PreferenceKey system.
    ///
    /// - Parameter space: the named coordinate space of the **parent** branch view
    ///   (`branchSpaceName`). All callers within the same thread group must use the
    ///   same space so positions are comparable when the connector column draws.
    func reportCommentThreadAnchor(
        space: CoordinateSpace,
        threadGroupId: UUID,
        commentId: UUID,
        role: CommentThreadAnchorRole
    ) -> some View {
        background {
            GeometryReader { proxy in
                let frame = proxy.frame(in: space)
                Color.clear.preference(
                    key: CommentThreadMetricsKey.self,
                    value: metricsPatch(
                        threadGroupId: threadGroupId,
                        commentId: commentId,
                        role: role,
                        frame: frame
                    )
                )
            }
        }
    }

    private func metricsPatch(
        threadGroupId: UUID,
        commentId: UUID,
        role: CommentThreadAnchorRole,
        frame: CGRect
    ) -> [UUID: CommentThreadMetrics] {
        switch role {
        case .threadStart:
            [
                threadGroupId: CommentThreadMetrics(
                    threadStartY: frame.maxY + CommentThreadLayout.gapBelowAvatar
                ),
            ]
        case .avatarCenter:
            [
                threadGroupId: CommentThreadMetrics(
                    avatarCenters: [commentId: CGPoint(x: frame.midX, y: frame.midY)]
                ),
            ]
        }
    }
}
