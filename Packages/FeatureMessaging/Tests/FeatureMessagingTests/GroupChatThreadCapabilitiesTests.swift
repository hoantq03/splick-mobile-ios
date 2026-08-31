import XCTest
@testable import FeatureMessaging

final class GroupChatThreadCapabilitiesTests: XCTestCase {

    func testOwnerHasManagementActions() {
        let caps = GroupChatThreadCapabilities.resolve(
            isGroup: true,
            isRemoved: false,
            isOwner: true
        )
        XCTAssertTrue(caps.canChangeAvatar)
        XCTAssertTrue(caps.canRename)
        XCTAssertTrue(caps.canManageMembers)
        XCTAssertTrue(caps.canInviteMembers)
        XCTAssertTrue(caps.canLeave)
        XCTAssertTrue(caps.canInteractWithMessages)
    }

    func testMemberCannotRenameOrChangeAvatar() {
        let caps = GroupChatThreadCapabilities.resolve(
            isGroup: true,
            isRemoved: false,
            isOwner: false
        )
        XCTAssertFalse(caps.canChangeAvatar)
        XCTAssertFalse(caps.canRename)
        XCTAssertTrue(caps.canManageMembers)
        XCTAssertTrue(caps.canInviteMembers)
        XCTAssertTrue(caps.canLeave)
        XCTAssertTrue(caps.canInteractWithMessages)
    }

    func testRemovedIsReadOnlyAsideFromSearchAndDelete() {
        let caps = GroupChatThreadCapabilities.resolve(
            isGroup: true,
            isRemoved: true,
            isOwner: true
        )
        XCTAssertTrue(caps.canSearch)
        XCTAssertTrue(caps.canManageNotifications)
        XCTAssertTrue(caps.canDeleteConversation)
        XCTAssertFalse(caps.canChangeAvatar)
        XCTAssertFalse(caps.canRename)
        XCTAssertFalse(caps.canManageMembers)
        XCTAssertFalse(caps.canInviteMembers)
        XCTAssertFalse(caps.canLeave)
        XCTAssertFalse(caps.canInteractWithMessages)
    }
}
