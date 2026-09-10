import XCTest
import DesignSystem
@testable import FeatureMessaging

final class SplickEdgeInteractivePopTests: XCTestCase {

    func testLeadingBandMatchesEdgeWidthConstant() {
        let width = SplickEdgeInteractivePop.edgeWidth
        XCTAssertEqual(width, 20, accuracy: 0.1)

        // Exclusive band: [0, width)
        XCTAssertTrue(
            SplickEdgeInteractivePop.isInLeadingEdgeBand(x: 0, viewWidth: 390, isRightToLeft: false)
        )
        XCTAssertTrue(
            SplickEdgeInteractivePop.isInLeadingEdgeBand(
                x: width - 0.5,
                viewWidth: 390,
                isRightToLeft: false
            )
        )
        XCTAssertFalse(
            SplickEdgeInteractivePop.isInLeadingEdgeBand(x: width, viewWidth: 390, isRightToLeft: false)
        )
        XCTAssertFalse(
            SplickEdgeInteractivePop.isInLeadingEdgeBand(x: 40, viewWidth: 390, isRightToLeft: false)
        )
    }

    func testTrailingBandForRightToLeft() {
        let width = SplickEdgeInteractivePop.edgeWidth
        XCTAssertTrue(
            SplickEdgeInteractivePop.isInLeadingEdgeBand(x: 390, viewWidth: 390, isRightToLeft: true)
        )
        XCTAssertTrue(
            SplickEdgeInteractivePop.isInLeadingEdgeBand(
                x: 390 - width + 0.5,
                viewWidth: 390,
                isRightToLeft: true
            )
        )
        XCTAssertFalse(
            SplickEdgeInteractivePop.isInLeadingEdgeBand(
                x: 390 - width,
                viewWidth: 390,
                isRightToLeft: true
            )
        )
        XCTAssertFalse(
            SplickEdgeInteractivePop.isInLeadingEdgeBand(x: 0, viewWidth: 390, isRightToLeft: true)
        )
    }

    func testBezelCoversAvatarLeadingButBubbleMidIsOutside() {
        let padding = MessageThreadRowLayout.listHorizontalPadding
        let avatarSize = MessageThreadRowLayout.senderAvatarSize
        let gutter = MessageThreadRowLayout.senderAvatarGutter
        let widths: [CGFloat] = [375, 390, 430]

        for viewWidth in widths {
            let edge = SplickEdgeInteractivePop.edgeWidth
            XCTAssertTrue(
                SplickEdgeInteractivePop.isInLeadingEdgeBand(
                    x: 0,
                    viewWidth: viewWidth,
                    isRightToLeft: false
                )
            )
            // Left portion of the avatar sits inside the wider bezel — contentOwnsTouch must yield.
            let avatarLeading = padding
            XCTAssertTrue(
                SplickEdgeInteractivePop.isInLeadingEdgeBand(
                    x: avatarLeading,
                    viewWidth: viewWidth,
                    isRightToLeft: false
                ),
                "width \(viewWidth): avatar leading needs contentOwnsTouch"
            )
            // Avatar center (padding + 16 = 24) is past the 20pt bezel.
            let avatarCenter = padding + avatarSize / 2
            XCTAssertFalse(
                SplickEdgeInteractivePop.isInLeadingEdgeBand(
                    x: avatarCenter,
                    viewWidth: viewWidth,
                    isRightToLeft: false
                ),
                "width \(viewWidth): avatar center x=\(avatarCenter)"
            )

            let bubbleMidX = padding + gutter + 80
            XCTAssertFalse(
                SplickEdgeInteractivePop.isInLeadingEdgeBand(
                    x: bubbleMidX,
                    viewWidth: viewWidth,
                    isRightToLeft: false
                ),
                "width \(viewWidth): bubble mid x=\(bubbleMidX)"
            )
            XCTAssertGreaterThan(edge, padding)
        }
    }

    func testResolvedEdgeWidthAddsLeadingSafeArea() {
        let base = SplickEdgeInteractivePop.edgeWidth
        let notch: CGFloat = 47
        let resolved = notch + base
        XCTAssertTrue(
            SplickEdgeInteractivePop.isInLeadingEdgeBand(
                x: notch + base - 1,
                viewWidth: 844,
                isRightToLeft: false,
                edgeWidth: resolved
            )
        )
        XCTAssertFalse(
            SplickEdgeInteractivePop.isInLeadingEdgeBand(
                x: notch + base,
                viewWidth: 844,
                isRightToLeft: false,
                edgeWidth: resolved
            )
        )
    }

    func testHorizontalDominantPopRejectsVerticalPull() {
        XCTAssertFalse(
            SplickInteractivePopAxis.isOutwardHorizontalPop(
                translation: CGPoint(x: 4, y: -28),
                isRightToLeft: false
            )
        )
        XCTAssertTrue(
            SplickInteractivePopAxis.isOutwardHorizontalPop(
                translation: CGPoint(x: 24, y: 6),
                isRightToLeft: false
            )
        )
    }
}

final class ChatSwipeHitTestingTests: XCTestCase {
    private let bubble = CGRect(x: 46, y: 100, width: 160, height: 40)
    private let gutter: CGFloat = MessageThreadRowLayout.senderAvatarGutter

    func testIncomingHitIncludesAvatarGutter() {
        let hit = ChatSwipeHitTesting.replyHitFrame(
            bubbleFrame: bubble,
            isOutgoing: false,
            isRightToLeft: false,
            avatarGutter: gutter
        )
        let avatarPoint = CGPoint(x: bubble.minX - gutter / 2, y: bubble.midY)
        XCTAssertTrue(hit.contains(avatarPoint))
        XCTAssertTrue(hit.contains(CGPoint(x: bubble.midX, y: bubble.midY)))
        XCTAssertEqual(
            hit.minX,
            bubble.minX - ChatSwipeHitTesting.bubbleHitInsetX - gutter,
            accuracy: 0.1
        )
    }

    func testIncomingAvatarAndBubbleHitFramesCoverReplyZone() {
        let padding = MessageThreadRowLayout.listHorizontalPadding
        let avatarSize = MessageThreadRowLayout.senderAvatarSize
        let bubbleFrame = CGRect(
            x: padding + MessageThreadRowLayout.senderAvatarGutter,
            y: 100,
            width: 160,
            height: 40
        )
        let hit = ChatSwipeHitTesting.replyHitFrame(
            bubbleFrame: bubbleFrame,
            isOutgoing: false,
            isRightToLeft: false,
            avatarGutter: gutter
        )
        let avatarLeading = CGPoint(x: padding, y: bubbleFrame.midY)
        let avatarCenter = CGPoint(x: padding + avatarSize / 2, y: bubbleFrame.midY)
        let bubbleMid = CGPoint(x: bubbleFrame.midX, y: bubbleFrame.midY)
        XCTAssertTrue(hit.contains(avatarLeading))
        XCTAssertTrue(hit.contains(avatarCenter))
        XCTAssertTrue(hit.contains(bubbleMid))
    }

    func testOutgoingHitDoesNotExpandLeading() {
        let hit = ChatSwipeHitTesting.replyHitFrame(
            bubbleFrame: bubble,
            isOutgoing: true,
            isRightToLeft: false,
            avatarGutter: gutter
        )
        let leftOfBubble = CGPoint(x: bubble.minX - gutter / 2, y: bubble.midY)
        XCTAssertFalse(hit.contains(leftOfBubble))
        XCTAssertEqual(
            hit.minX,
            bubble.minX - ChatSwipeHitTesting.bubbleHitInsetX,
            accuracy: 0.1
        )
    }

    func testIncomingRTLExpandsTrailing() {
        let hit = ChatSwipeHitTesting.replyHitFrame(
            bubbleFrame: bubble,
            isOutgoing: false,
            isRightToLeft: true,
            avatarGutter: gutter
        )
        let trailingAvatar = CGPoint(x: bubble.maxX + gutter / 2, y: bubble.midY)
        XCTAssertTrue(hit.contains(trailingAvatar))
        XCTAssertEqual(
            hit.maxX,
            bubble.maxX + ChatSwipeHitTesting.bubbleHitInsetX + gutter,
            accuracy: 0.1
        )
    }
}
