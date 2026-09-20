import XCTest
import SplickDomain
import Common
import Localization
import Storage
@testable import FeatureMessaging

private final class MockUserDefaultsForNotice: UserDefaultsServiceProtocol {
    private var dict: [String: Any] = [:]
    func set<T: Codable>(_ value: T, for key: String) { dict[key] = value }
    func get<T: Codable>(for key: String) -> T? { dict[key] as? T }
    func setBool(_ value: Bool, for key: String) { dict[key] = value }
    func getBool(for key: String) -> Bool { (dict[key] as? Bool) ?? false }
    func remove(for key: String) { dict.removeValue(forKey: key) }
}

final class MessagingPresentationHelpersTests: XCTestCase {

    func testGroupChatThreadCapabilities() {
        let ownerCaps = GroupChatThreadCapabilities.resolve(isGroup: true, isRemoved: false, isOwner: true)
        XCTAssertEqual(ownerCaps, .owner)
        XCTAssertTrue(ownerCaps.canDisbandGroup)
        XCTAssertTrue(ownerCaps.canChangeAvatar)
        XCTAssertTrue(ownerCaps.canRename)
        XCTAssertTrue(ownerCaps.canInteractWithMessages)

        let memberCaps = GroupChatThreadCapabilities.resolve(isGroup: true, isRemoved: false, isOwner: false)
        XCTAssertEqual(memberCaps, .member)
        XCTAssertFalse(memberCaps.canDisbandGroup)
        XCTAssertFalse(memberCaps.canChangeAvatar)
        XCTAssertTrue(memberCaps.canInteractWithMessages)

        let removedCaps = GroupChatThreadCapabilities.resolve(isGroup: true, isRemoved: true, isOwner: false)
        XCTAssertEqual(removedCaps, .removed)
        XCTAssertFalse(removedCaps.canInteractWithMessages)
        XCTAssertFalse(removedCaps.canLeave)

        let directCaps = GroupChatThreadCapabilities.resolve(isGroup: false, isRemoved: false, isOwner: false)
        XCTAssertEqual(directCaps, .directDefaults)
        XCTAssertTrue(directCaps.canInteractWithMessages)

        XCTAssertEqual(GroupChatThreadCapabilities.forRole(.owner), .owner)
        XCTAssertEqual(GroupChatThreadCapabilities.forRole(.member), .member)
        XCTAssertEqual(GroupChatThreadCapabilities.forRole(.removed), .removed)
    }

    func testGroupSystemNoticePayload() {
        let normalMsg = ChatMessage(
            id: UUID(),
            conversationId: UUID(),
            senderId: UUID(),
            body: "Normal chat text",
            clientMessageId: UUID(),
            createdAt: Date()
        )
        XCTAssertFalse(GroupSystemNoticePayload.displaysAsSystemNotice(normalMsg))
        XCTAssertFalse(GroupSystemNoticePayload.isMemberLeft(normalMsg.body))
        XCTAssertEqual(GroupSystemNoticePayload.memberLeftDisplayName(normalMsg.body), "Normal chat text")

        let leaverBody = "\(GroupSystemNoticePayload.memberLeftPrefix) John Doe"
        let leaveMsg = ChatMessage(
            id: UUID(),
            conversationId: UUID(),
            senderId: UUID(),
            body: leaverBody,
            clientMessageId: UUID(),
            createdAt: Date()
        )
        XCTAssertTrue(GroupSystemNoticePayload.displaysAsSystemNotice(leaveMsg))
        XCTAssertTrue(GroupSystemNoticePayload.isMemberLeft(leaveMsg.body))
        XCTAssertEqual(GroupSystemNoticePayload.memberLeftDisplayName(leaveMsg.body), "John Doe")
    }

    @MainActor
    func testGroupSystemNoticeCopy() {
        let lang = LanguageService(userDefaults: MockUserDefaultsForNotice())
        let myId = UUID()
        let otherId = UUID()

        let renamedByMe = ChatMessage(
            id: UUID(),
            conversationId: UUID(),
            senderId: myId,
            body: "New Group Name",
            clientMessageId: UUID(),
            createdAt: Date(),
            type: .groupRenamed
        )
        let copy1 = GroupSystemNoticeCopy.text(message: renamedByMe, currentUserId: myId, actorName: "Me", languageService: lang)
        XCTAssertFalse(copy1.isEmpty)

        let renamedByOther = ChatMessage(
            id: UUID(),
            conversationId: UUID(),
            senderId: otherId,
            body: "Another Name",
            clientMessageId: UUID(),
            createdAt: Date(),
            type: .groupRenamed
        )
        let copy2 = GroupSystemNoticeCopy.text(message: renamedByOther, currentUserId: myId, actorName: "Alice", languageService: lang)
        XCTAssertFalse(copy2.isEmpty)

        let copy2Unknown = GroupSystemNoticeCopy.text(message: renamedByOther, currentUserId: myId, actorName: nil, languageService: lang)
        XCTAssertFalse(copy2Unknown.isEmpty)

        let memberAddedByMe = ChatMessage(
            id: UUID(),
            conversationId: UUID(),
            senderId: myId,
            body: "Bob",
            clientMessageId: UUID(),
            createdAt: Date(),
            type: .groupMemberAdded
        )
        let copy3 = GroupSystemNoticeCopy.text(message: memberAddedByMe, currentUserId: myId, actorName: "Me", languageService: lang)
        XCTAssertFalse(copy3.isEmpty)

        let memberAddedByOther = ChatMessage(
            id: UUID(),
            conversationId: UUID(),
            senderId: otherId,
            body: "Bob",
            clientMessageId: UUID(),
            createdAt: Date(),
            type: .groupMemberAdded
        )
        let copy3Other = GroupSystemNoticeCopy.text(message: memberAddedByOther, currentUserId: myId, actorName: "Alice", languageService: lang)
        XCTAssertFalse(copy3Other.isEmpty)
        let copy3Unknown = GroupSystemNoticeCopy.text(message: memberAddedByOther, currentUserId: myId, actorName: nil, languageService: lang)
        XCTAssertFalse(copy3Unknown.isEmpty)

        let leftByMe = ChatMessage(
            id: UUID(),
            conversationId: UUID(),
            senderId: myId,
            body: "\(GroupSystemNoticePayload.memberLeftPrefix) Me",
            clientMessageId: UUID(),
            createdAt: Date(),
            type: .groupMemberLeft
        )
        let copy4 = GroupSystemNoticeCopy.text(message: leftByMe, currentUserId: myId, actorName: "Me", languageService: lang)
        XCTAssertFalse(copy4.isEmpty)

        let leftByOther = ChatMessage(
            id: UUID(),
            conversationId: UUID(),
            senderId: otherId,
            body: "\(GroupSystemNoticePayload.memberLeftPrefix) Bob",
            clientMessageId: UUID(),
            createdAt: Date(),
            type: .groupMemberLeft
        )
        let copy4Other = GroupSystemNoticeCopy.text(message: leftByOther, currentUserId: myId, actorName: "Bob", languageService: lang)
        XCTAssertFalse(copy4Other.isEmpty)

        let removedByMe = ChatMessage(
            id: UUID(),
            conversationId: UUID(),
            senderId: myId,
            body: "Bob",
            clientMessageId: UUID(),
            createdAt: Date(),
            type: .groupMemberRemoved
        )
        let copy5 = GroupSystemNoticeCopy.text(message: removedByMe, currentUserId: myId, actorName: "Me", languageService: lang)
        XCTAssertFalse(copy5.isEmpty)

        let removedByOther = ChatMessage(
            id: UUID(),
            conversationId: UUID(),
            senderId: otherId,
            body: "Bob",
            clientMessageId: UUID(),
            createdAt: Date(),
            type: .groupMemberRemoved
        )
        let copy5Other = GroupSystemNoticeCopy.text(message: removedByOther, currentUserId: myId, actorName: "Admin", languageService: lang)
        XCTAssertFalse(copy5Other.isEmpty)
        let copy5Unknown = GroupSystemNoticeCopy.text(message: removedByOther, currentUserId: myId, actorName: nil, languageService: lang)
        XCTAssertFalse(copy5Unknown.isEmpty)

        let deletedByMe = ChatMessage(
            id: UUID(),
            conversationId: UUID(),
            senderId: myId,
            body: "",
            clientMessageId: UUID(),
            createdAt: Date(),
            type: .groupDeleted
        )
        let copy6 = GroupSystemNoticeCopy.text(message: deletedByMe, currentUserId: myId, actorName: "Me", languageService: lang)
        XCTAssertFalse(copy6.isEmpty)

        let deletedByOther = ChatMessage(
            id: UUID(),
            conversationId: UUID(),
            senderId: otherId,
            body: "",
            clientMessageId: UUID(),
            createdAt: Date(),
            type: .groupDeleted
        )
        let copy6Other = GroupSystemNoticeCopy.text(message: deletedByOther, currentUserId: myId, actorName: "Owner", languageService: lang)
        XCTAssertFalse(copy6Other.isEmpty)
        let copy6Unknown = GroupSystemNoticeCopy.text(message: deletedByOther, currentUserId: myId, actorName: nil, languageService: lang)
        XCTAssertFalse(copy6Unknown.isEmpty)

        let transferredByMe = ChatMessage(
            id: UUID(),
            conversationId: UUID(),
            senderId: myId,
            body: "NewAdmin",
            clientMessageId: UUID(),
            createdAt: Date(),
            type: .groupAdminTransferred
        )
        let copy7 = GroupSystemNoticeCopy.text(message: transferredByMe, currentUserId: myId, actorName: "Me", languageService: lang)
        XCTAssertFalse(copy7.isEmpty)

        let transferredByOther = ChatMessage(
            id: UUID(),
            conversationId: UUID(),
            senderId: otherId,
            body: "NewAdmin",
            clientMessageId: UUID(),
            createdAt: Date(),
            type: .groupAdminTransferred
        )
        let copy7Other = GroupSystemNoticeCopy.text(message: transferredByOther, currentUserId: myId, actorName: "OldAdmin", languageService: lang)
        XCTAssertFalse(copy7Other.isEmpty)
        let copy7Unknown = GroupSystemNoticeCopy.text(message: transferredByOther, currentUserId: myId, actorName: nil, languageService: lang)
        XCTAssertFalse(copy7Unknown.isEmpty)
    }

    func testMessageAttachmentMapper() {
        let mediaId = UUID()
        let imgUrl = URL(string: "https://example.com/image.png")!
        let thumbUrl = URL(string: "https://example.com/thumb.png")!

        let imageSubmission = CommentSubmissionAttachment(
            kind: .image,
            uploadedMediaId: mediaId,
            url: imgUrl,
            thumbnailURL: thumbUrl,
            sizeBytes: 1024
        )
        let mappedImage = MessageAttachmentMapper.messageImage(from: imageSubmission)
        XCTAssertNotNil(mappedImage)
        XCTAssertEqual(mappedImage?.mediaId, mediaId)
        XCTAssertEqual(mappedImage?.url, imgUrl)
        XCTAssertEqual(mappedImage?.thumbnailURL, thumbUrl)

        let gifSubmission = CommentSubmissionAttachment(
            kind: .gif,
            remoteURL: imgUrl
        )
        let mappedGif = MessageAttachmentMapper.messageGif(from: gifSubmission)
        XCTAssertNotNil(mappedGif)
        XCTAssertEqual(mappedGif?.url, imgUrl)
        XCTAssertNil(mappedGif?.mediaId)

        // Negative cases
        XCTAssertNil(MessageAttachmentMapper.messageImage(from: gifSubmission))
        XCTAssertNil(MessageAttachmentMapper.messageGif(from: imageSubmission))

        XCTAssertGreaterThan(MessageImageLimits.maxImages, 0)
    }

    func testMessageBodyLinkifier() {
        let plainText = "Hello world"
        let plainAttr = MessageBodyLinkifier.attributed(plainText, isOutgoing: true)
        XCTAssertEqual(String(plainAttr.characters), plainText)

        let urlText = "Visit https://splick.app for details"
        let urlAttr = MessageBodyLinkifier.attributed(urlText, isOutgoing: false)
        XCTAssertEqual(String(urlAttr.characters), urlText)

        let detectedUrls = MessageBodyLinkifier.urls(in: urlText)
        XCTAssertEqual(detectedUrls.count, 1)
        XCTAssertEqual(detectedUrls.first?.host, "splick.app")

        XCTAssertTrue(MessageBodyLinkifier.urls(in: "No links here").isEmpty)
    }

    func testMessageTimeSeparatorFormatterDifferentYearsAndWeeks() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!

        let now = Date(timeIntervalSince1970: 1700000000) // Base time
        let twoWeeksAgo = cal.date(byAdding: .day, value: -14, to: now)!
        let threeDaysAgo = cal.date(byAdding: .day, value: -3, to: now)!
        let lastYear = cal.date(byAdding: .year, value: -1, to: now)!

        let s1 = MessageTimeSeparatorFormatter.string(
            from: threeDaysAgo,
            locale: .en,
            yesterdayLabel: "Yesterday",
            now: now,
            calendar: cal
        )
        XCTAssertFalse(s1.isEmpty)

        let s2 = MessageTimeSeparatorFormatter.string(
            from: twoWeeksAgo,
            locale: .en,
            yesterdayLabel: "Yesterday",
            now: now,
            calendar: cal
        )
        XCTAssertFalse(s2.isEmpty)

        let s3 = MessageTimeSeparatorFormatter.string(
            from: lastYear,
            locale: .en,
            yesterdayLabel: "Yesterday",
            now: now,
            calendar: cal
        )
        XCTAssertFalse(s3.isEmpty)
    }
}
