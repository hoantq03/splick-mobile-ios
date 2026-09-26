import XCTest
@testable import SplickDomain

final class SplickDomainComprehensiveCoverageTests: XCTestCase {

    // MARK: - AlbumPhoto & StickerCategory & MessageEditDraft & UploadedMediaReference & MessageImageAttachment
    func testRemainingLeafEntities() {
        let author = UserSummary(id: UUID(), username: "alice", displayName: "Alice")
        let companion = UserSummary(id: UUID(), username: "bob", displayName: "Bob")
        let album = AlbumPhoto(
            id: UUID(),
            postId: UUID(),
            author: author,
            groupId: UUID(),
            caption: "Trip",
            mediaURL: URL(string: "https://example.com/photo.jpg")!,
            thumbnailURL: URL(string: "https://example.com/thumb.jpg")!,
            mediaType: .image,
            sortOrder: 0,
            createdAt: Date(),
            checkInPlace: "Da Lat",
            companions: [companion]
        )
        XCTAssertEqual(album.checkInPlace, "Da Lat")
        XCTAssertEqual(album.companions.count, 1)

        let stickerCat = StickerCategory(
            id: "cat-1",
            name: "Anime",
            previewURL: URL(string: "https://example.com/cat.png")
        )
        XCTAssertEqual(stickerCat.id, "cat-1")
        XCTAssertEqual(stickerCat.name, "Anime")
        XCTAssertNotNil(stickerCat.previewURL)

        let editDraft = MessageEditDraft(messageId: UUID(), originalBody: "Hello world")
        XCTAssertEqual(editDraft.originalBody, "Hello world")

        let uploadRef = UploadedMediaReference(
            id: UUID(),
            url: URL(string: "https://example.com/up.mp4")!,
            thumbnailURL: URL(string: "https://example.com/up_thumb.jpg")!,
            sizeBytes: 2048
        )
        XCTAssertEqual(uploadRef.sizeBytes, 2048)

        let msgAttachment = MessageImageAttachment(
            mediaId: UUID(),
            url: URL(string: "https://example.com/msg.jpg")!,
            thumbnailURL: URL(string: "https://example.com/msg_th.jpg")
        )
        XCTAssertNotNil(msgAttachment.mediaId)
        XCTAssertNotNil(msgAttachment.thumbnailURL)
    }

    // MARK: - PreviewData (DEBUG)
    func testPreviewDataCoverage() {
        #if DEBUG
        XCTAssertEqual(PreviewData.currentUser.username, "namtran")
        XCTAssertEqual(PreviewData.friendUser.username, "linhpham")
        XCTAssertEqual(PreviewData.friend2.username, "ducnguyen")
        XCTAssertFalse(PreviewData.samplePosts.isEmpty)
        XCTAssertFalse(PreviewData.sampleExpenses.isEmpty)
        XCTAssertFalse(PreviewData.sampleDebts.isEmpty)
        XCTAssertFalse(PreviewData.sampleNotifications.isEmpty)
        XCTAssertEqual(PreviewData.sampleGroup.name, "Roommates Q7")
        #endif
    }

    // MARK: - Post Extended Coverage (canDelete, isViewed, hasMultipleMedia, knownUsers, userReactionSummaries, etc.)
    func testPostExtendedCoverage() {
        let author = UserSummary(id: UUID(), username: "alice", displayName: "Alice")
        let userB = UserSummary(id: UUID(), username: "bob", displayName: "Bob")
        let userC = UserSummary(id: UUID(), username: "charlie", displayName: "Charlie")
        let postImg = URL(string: "https://example.com/1.jpg")!

        let media1 = PostMediaItem(mediaURL: postImg, mediaType: .image, sortOrder: 0)
        let media2 = PostMediaItem(mediaURL: URL(string: "https://example.com/2.jpg")!, mediaType: .image, sortOrder: 1)

        let post = Post(
            id: UUID(),
            author: author,
            imageURL: postImg,
            mediaItems: [media1, media2],
            viewers: [userB],
            mentions: [userC],
            editedAt: Date()
        )

        // isEdited
        XCTAssertTrue(post.isEdited)

        // Equality operator ==
        let postSameVersion = post.withVersion(post.version)
        XCTAssertTrue(post == postSameVersion)
        let postDiffVersion = post.withVersion(post.version + 1)
        XCTAssertFalse(post == postDiffVersion)

        // hasMultipleMedia
        XCTAssertTrue(post.hasMultipleMedia)

        // isViewed
        XCTAssertTrue(post.isViewed(by: nil))
        XCTAssertTrue(post.isViewed(by: author.id))
        XCTAssertTrue(post.isViewed(by: userB.id))
        XCTAssertFalse(post.isViewed(by: userC.id))
        XCTAssertTrue(post.isViewed(by: userC.id, additionallyViewedIds: [post.id]))

        // canDelete
        XCTAssertTrue(post.canDelete) // checkIn post kind

        // Share bill post with evidence comment -> canDelete false
        let evidenceComment = PostComment(
            author: userB,
            text: "Payment receipt",
            commentType: .evidence,
            mentions: []
        )
        let shareBillWithEvidence = Post(
            id: UUID(),
            author: author,
            imageURL: postImg,
            comments: [evidenceComment],
            feedKind: .shareBill,
            mentions: []
        )
        XCTAssertFalse(shareBillWithEvidence.canDelete)

        // Share bill post with split having latestEvidenceCommentId -> canDelete false
        let splitWithEvidence = PostBillSplitLine(
            user: userB,
            amount: 50_000,
            isPaid: false,
            latestEvidenceCommentId: UUID()
        )
        let shareBillWithSplitEvidence = Post(
            id: UUID(),
            author: author,
            imageURL: postImg,
            feedKind: .shareBill,
            billSplit: PostBillSplit(totalAmount: 50_000, currency: "VND", splits: [splitWithEvidence]),
            mentions: []
        )
        XCTAssertFalse(shareBillWithSplitEvidence.canDelete)

        // knownUsers coverage
        let known = post.knownUsers
        XCTAssertNotNil(known[author.id])
        XCTAssertNotNil(known[userB.id])
        XCTAssertNotNil(known[userC.id])

        // UserReactionSummary properties
        let uSummary = UserReactionSummary(
            user: author,
            emojiCounts: [
                UserEmojiCount(emoji: "❤️", count: 3),
                UserEmojiCount(emoji: "🔥", count: 2)
            ]
        )
        XCTAssertEqual(uSummary.id, author.id)
        XCTAssertEqual(uSummary.totalCount, 5)

        // userReactionSummaries aggregation from raw reactions
        let r1 = Reaction(id: UUID(), emoji: "❤️", userId: userB.id)
        let r2 = Reaction(id: UUID(), emoji: "❤️", userId: userB.id)
        let r3 = Reaction(id: UUID(), emoji: "🔥", userId: userC.id)
        let postWithReactions = Post(
            id: UUID(),
            author: author,
            imageURL: postImg,
            reactions: [r1, r2, r3],
            reactorCount: 2,
            mentions: []
        )
        let summaries = postWithReactions.userReactionSummaries()
        XCTAssertEqual(summaries.count, 2)
        XCTAssertEqual(summaries.first?.userId, userB.id)
        XCTAssertEqual(summaries.first?.totalCount, 2)

        // reactionPreview fallback to userReactionSummaries when server preview empty
        let preview = postWithReactions.reactionPreview(topLimit: 1)
        XCTAssertEqual(preview.top.count, 1)
        XCTAssertEqual(preview.otherPeopleCount, 1)

        // GuestParticipant and PostBillSplitLine guest properties
        let guest = GuestParticipant(displayName: "Duy Guest", status: "pending")
        let guestLine = PostBillSplitLine(guest: guest, amount: 25_000)
        XCTAssertEqual(guestLine.participantDisplayName, "Duy Guest")
        XCTAssertTrue(guestLine.isPendingGuest)

        let userLine = PostBillSplitLine(user: userB, amount: 25_000)
        XCTAssertEqual(userLine.participantDisplayName, "Bob")
        XCTAssertFalse(userLine.isPendingGuest)

        // Post.updating covering all parameters
        let newComments = [
            PostComment(author: userB, text: "Hey", mentions: []),
            PostComment(author: userC, text: "Deleted", deletedAt: Date(), mentions: [])
        ]
        let updatedPost = post.updating(
            reactions: [r1],
            reactionCount: 1,
            reactorCount: 1,
            reactionPreview: [uSummary],
            comments: newComments,
            viewCount: 10,
            viewers: [userB, userC],
            mediaItems: [media1],
            billSplit: PostBillSplit(totalAmount: 100_000, currency: "VND", splits: []),
            companionGroupName: "Group Name",
            caption: "New Caption",
            editedAt: Date()
        )
        XCTAssertEqual(updatedPost.commentCount, 1) // 1 active, 1 deleted
        XCTAssertEqual(updatedPost.viewCount, 10)
        XCTAssertEqual(updatedPost.caption, "New Caption")
        XCTAssertEqual(updatedPost.companionGroupName, "Group Name")

        // Post.updating with explicit commentCount
        let explicitCountPost = post.updating(commentCount: 99)
        XCTAssertEqual(explicitCountPost.commentCount, 99)

        // Post.userForMentionUsername
        let mentionedAuthor = post.userForMentionUsername("@alice")
        XCTAssertEqual(mentionedAuthor?.id, author.id)
        let mentionedBob = post.userForMentionUsername("<@\(userB.id.uuidString)>")
        XCTAssertEqual(mentionedBob?.id, userB.id)
        XCTAssertNil(post.userForMentionUsername("unknown_user"))
        XCTAssertNil(post.userForMentionUsername("   "))

        // Repeated reaction with same emoji on existing user in preview
        var multiReacted = postWithReactions.applyingOptimisticReaction(
            emoji: "❤️",
            reactionId: UUID(),
            user: userB
        )
        // Another reaction with new emoji for same user
        multiReacted = multiReacted.applyingOptimisticReaction(
            emoji: "🎉",
            reactionId: UUID(),
            user: userB
        )
        XCTAssertEqual(multiReacted.reactionCount, 5)

        // Remove the newly added emoji
        let unReactedPartial = multiReacted.removingOptimisticReaction(
            reactionId: UUID(),
            emoji: "🎉",
            userId: userB.id
        )
        XCTAssertEqual(unReactedPartial.reactionCount, 4)
    }



    // MARK: - AppNotification & NotificationType & NotificationDestination Coverage
    func testAppNotificationAndDestinationDeepCoverage() {
        let actorId = UUID()
        let refId = UUID()
        let notif = AppNotification(
            id: UUID(),
            type: .friendRequestSent,
            title: "Request",
            body: "Alice sent you a request",
            referenceId: refId,
            actorUserId: actorId
        )
        XCTAssertTrue(notif.canRespondToFriendRequest)

        let readNotif = notif.markingAsRead()
        XCTAssertTrue(readNotif.isRead)

        // Navigation target fallbacks across types
        let expensesTypes: [NotificationType] = [
            .expenseSplitBill, .expenseReminder, .expenseSettled,
            .dailyDebtReminder, .bulkSettlementPendingApproval,
            .bulkSettlementApproved, .bulkSettlementRejected
        ]
        for t in expensesTypes {
            let n = AppNotification(id: UUID(), type: t, title: "T", body: "B")
            XCTAssertEqual(n.navigationTarget, .expenses)
            XCTAssertTrue(t.isExpensesDirectoryNotification)
        }

        let feedTypes: [NotificationType] = [
            .streakReminderMidday, .streakReminderEvening
        ]
        for t in feedTypes {
            let n = AppNotification(id: UUID(), type: t, title: "T", body: "B")
            XCTAssertEqual(n.navigationTarget, .feed)
        }

        let friendsTypes: [NotificationType] = [
            .groupInvite, .groupDeleted
        ]
        for t in friendsTypes {
            let n = AppNotification(id: UUID(), type: t, title: "T", body: "B")
            XCTAssertEqual(n.navigationTarget, .friends)
        }

        // destination screen inbox
        let inboxNotif = AppNotification(
            id: UUID(),
            type: .system,
            title: "T",
            body: "B",
            destination: NotificationDestination(screen: .inbox)
        )
        XCTAssertEqual(inboxNotif.navigationTarget, .inbox)

        // postDetail screen without referenceId -> fallback .feed
        let postDetailNoRef = AppNotification(
            id: UUID(),
            type: .postCommented,
            title: "T",
            body: "B",
            referenceId: nil,
            destination: NotificationDestination(screen: .postDetail)
        )
        XCTAssertEqual(postDetailNoRef.navigationTarget, .feed)

        // friendRequestAccepted / NicknameChanged without actorUserId -> .friends
        let acceptedNoActor = AppNotification(
            id: UUID(),
            type: .friendRequestAccepted,
            title: "T",
            body: "B",
            actorUserId: nil
        )
        XCTAssertEqual(acceptedNoActor.navigationTarget, .friends)

        let nickNoActor = AppNotification(
            id: UUID(),
            type: .friendNicknameChanged,
            title: "T",
            body: "B",
            actorUserId: nil
        )
        XCTAssertEqual(nickNoActor.navigationTarget, .friends)

        // feedTaggedInPost without referenceId -> .feed
        let taggedNoRef = AppNotification(
            id: UUID(),
            type: .feedTaggedInPost,
            title: "T",
            body: "B",
            referenceId: nil
        )
        XCTAssertEqual(taggedNoRef.navigationTarget, .feed)

        let msgTypes: [NotificationType] = [
            .directMessage, .groupMessage, .groupCreated, .groupMemberAdded,
            .groupMemberRemoved, .groupRenamed, .groupAdminTransferred
        ]

        for t in msgTypes {
            let nWithRef = AppNotification(id: UUID(), type: t, title: "T", body: "B", referenceId: refId)
            XCTAssertEqual(nWithRef.navigationTarget, .conversation(refId))
            let nNoRef = AppNotification(id: UUID(), type: t, title: "T", body: "B")
            XCTAssertEqual(nNoRef.navigationTarget, .messages)
            XCTAssertTrue(t.isMessagingNotification)
        }

        let systemNotif = AppNotification(id: UUID(), type: .system, title: "T", body: "B")
        XCTAssertEqual(systemNotif.navigationTarget, .none)

        // NotificationType icons & category flags
        for t in [NotificationType.postReactionMilestone, .feedTaggedInPost, .feedMentionedInPost, .postCommented] {
            XCTAssertTrue(t.isFeedContentNotification)
        }

        let allTypes: [NotificationType] = [
            .feedTaggedInPost, .postCommented, .postReactionMilestone, .feedMentionedInPost,
            .feedMentionedInComment, .paymentEvidenceSubmitted, .expenseSplitBill, .dailyDebtReminder,
            .bulkSettlementPendingApproval, .paymentEvidenceApproved, .expenseSettled, .bulkSettlementApproved,
            .paymentEvidenceRejected, .bulkSettlementRejected, .expenseReminder, .streakReminderMidday,
            .streakReminderEvening, .friendRequestSent, .friendRequestAccepted, .friendNicknameChanged,
            .groupInvite, .groupDeleted, .groupMessage, .groupCreated, .groupMemberAdded,
            .groupMemberRemoved, .groupRenamed, .groupAdminTransferred, .directMessage, .system
        ]
        for t in allTypes {
            XCTAssertFalse(t.icon.isEmpty)
        }

        // NotificationListCategory filterable cases and query values
        XCTAssertEqual(NotificationListCategory.filterableCases.count, 3)
        XCTAssertFalse(NotificationListCategory.all.isFiltered)
        XCTAssertTrue(NotificationListCategory.expenses.isFiltered)
        XCTAssertNil(NotificationListCategory.all.queryValue)
        XCTAssertEqual(NotificationListCategory.expenses.queryValue, "EXPENSES")
        XCTAssertEqual(NotificationListCategory.friends.queryValue, "FRIENDS")
        XCTAssertEqual(NotificationListCategory.posts.queryValue, "POSTS")

        // NotificationDestination parsing from string, raw push user info
        let dest = NotificationDestination(screen: "expenses")
        XCTAssertEqual(dest.screen, .expenses)

        // Push userInfo screen and destination parsing
        let fcm1 = NotificationDestination.fromPushUserInfo([
            "targetScreen": "FRIENDS"
        ])
        XCTAssertEqual(fcm1?.screen, .friends)

        let fcm2 = NotificationDestination.fromPushUserInfo([
            "screen": "POST_DETAIL",
            "postId": UUID().uuidString,
            "commentId": UUID().uuidString
        ])
        XCTAssertEqual(fcm2?.screen, .postDetail)
        XCTAssertNotNil(fcm2?.postDetailId)
        XCTAssertNotNil(fcm2?.commentId)

        let fcm3 = NotificationDestination.fromPushUserInfo([
            "type": "GROUP_DELETED"
        ])
        XCTAssertEqual(fcm3?.screen, .friends)

        // JSON payload string parsing in fromPushUserInfo
        let jsonPayload = "{\"screen\": \"MESSAGES\", \"conversationId\": \"\(UUID().uuidString)\"}"
        let fcmJson = NotificationDestination.fromPushUserInfo([
            "payload": jsonPayload
        ])
        XCTAssertEqual(fcmJson?.screen, .messages)
        XCTAssertNotNil(fcmJson?.conversationId)
    }

    // MARK: - PostAudience & PostComment & PaymentProfile & Expense
    func testPostAudienceAndCommentAndPaymentProfile() {
        // PostAudience
        let id1 = UUID()
        let audFriends = PostAudience(mode: .friends)
        XCTAssertFalse(audFriends.requiresSelection)

        let audGroups = PostAudience(mode: .groups, allowedGroupIds: [id1])
        XCTAssertFalse(audGroups.requiresSelection)
        let audGroupsEmpty = PostAudience(mode: .groups, allowedGroupIds: [])
        XCTAssertTrue(audGroupsEmpty.requiresSelection)

        let audSpecific = PostAudience(mode: .specificUsers, allowedUserIds: [id1])
        XCTAssertFalse(audSpecific.requiresSelection)
        let audSpecificEmpty = PostAudience(mode: .specificUsers, allowedUserIds: [])
        XCTAssertTrue(audSpecificEmpty.requiresSelection)

        let audExcept = PostAudience(mode: .friendsExcept, excludedUserIds: [id1])
        XCTAssertFalse(audExcept.requiresSelection)
        let audExceptEmpty = PostAudience(mode: .friendsExcept, excludedUserIds: [])
        XCTAssertTrue(audExceptEmpty.requiresSelection)

        // PostComment moderationOutcome & isEdited
        let author = UserSummary(id: UUID(), username: "u", displayName: "U")
        let modComment = PostComment(
            author: author,
            commentType: .evidenceModeration,
            evidenceStatus: .approved
        )
        XCTAssertEqual(modComment.moderationOutcome, .approved)
        XCTAssertTrue(modComment.isEvidenceModeration)
        XCTAssertFalse(modComment.isEdited)

        let now = Date()
        let editedComment = PostComment(
            author: author,
            createdAt: now,
            updatedAt: now.addingTimeInterval(5)
        )
        XCTAssertTrue(editedComment.isEdited)

        // PaymentProfile
        let fullProfile = PaymentProfile(
            userId: UUID(),
            qrImageURL: URL(string: "https://example.com/qr.png"),
            accountName: "Nguyen Van A",
            accountNumber: "123456789",
            bankName: "Techcombank",
            updatedAt: Date()
        )
        XCTAssertTrue(fullProfile.hasQrImage)
        XCTAssertTrue(fullProfile.hasBankDetails)
        XCTAssertFalse(fullProfile.hasPartialBankDetails)
        XCTAssertTrue(fullProfile.hasAnyContent)
        XCTAssertTrue(fullProfile.hasDisplayableBankFields)

        let partialProfile = PaymentProfile(
            userId: UUID(),
            qrImageURL: nil,
            accountName: "Nguyen Van A",
            accountNumber: nil,
            bankName: nil,
            updatedAt: Date()
        )
        XCTAssertFalse(partialProfile.hasQrImage)
        XCTAssertFalse(partialProfile.hasBankDetails)
        XCTAssertTrue(partialProfile.hasPartialBankDetails)
        XCTAssertTrue(partialProfile.hasAnyContent)
        XCTAssertTrue(partialProfile.hasDisplayableBankFields)

        // Expense displaySettledAt & deprecated displayName
        let settledDate = Date().addingTimeInterval(-100)
        let settledExpense = Expense(
            id: UUID(),
            description: "Taxi",
            totalAmount: 50_000,
            paidBy: author,
            settledAt: settledDate
        )
        XCTAssertEqual(settledExpense.displaySettledAt, settledDate)

        let splitWithDate = ExpenseSplit(
            id: UUID(),
            user: author,
            amount: 50_000,
            isPaid: true,
            paidAt: settledDate
        )
        let expenseWithSplitDate = Expense(
            id: UUID(),
            description: "Taxi",
            totalAmount: 50_000,
            paidBy: author,
            splits: [splitWithDate]
        )
        XCTAssertEqual(expenseWithSplitDate.displaySettledAt, settledDate)

        for cat in ExpenseCategory.allCases {
            _ = cat.displayName
        }
    }

    // MARK: - FriendRequestInboxActionPolicy Extended
    func testFriendRequestInboxPolicyExtended() {
        let reqId = UUID()
        let actorId = UUID()
        let notifWithActorOnly = AppNotification(
            id: UUID(),
            type: .friendRequestSent,
            title: "Request",
            body: "Alice sent you a friend request",
            referenceId: nil,
            actorUserId: actorId
        )

        let pendingWithMap = PendingIncomingFriendRequests(
            requestIdByRequester: [actorId: reqId]
        )
        XCTAssertTrue(pendingWithMap.requestIds.contains(reqId))
        XCTAssertTrue(pendingWithMap.requesterIds.contains(actorId))

        // actorUserId matching when referenceId is nil
        let showForActor = FriendRequestInboxActionPolicy.shouldShowRespondActions(
            for: notifWithActorOnly,
            hasStoredOutcome: false,
            pendingIncoming: pendingWithMap
        )
        XCTAssertTrue(showForActor)

        // Non-matching actor
        let notifOtherActor = AppNotification(
            id: UUID(),
            type: .friendRequestSent,
            title: "Request",
            body: "Other",
            referenceId: nil,
            actorUserId: UUID()
        )
        XCTAssertFalse(
            FriendRequestInboxActionPolicy.shouldShowRespondActions(
                for: notifOtherActor,
                hasStoredOutcome: false,
                pendingIncoming: pendingWithMap
            )
        )
    }

    // MARK: - UserSession Inferred Platforms
    func testUserSessionInferredPlatformExtended() {
        let now = Date()
        let deviceNames = [
            "My iOS 18.2 Device",
            "My iPadOS 17.1 Tablet",
            "Office macOS Studio",
            "Personal Android 14 Phone",
            "Work Windows 11 PC"
        ]

        for name in deviceNames {
            let session = UserSession(
                id: UUID(),
                deviceInfo: nil,
                deviceName: name,
                createdAt: now,
                expiresAt: now.addingTimeInterval(3600),
                isCurrent: false
            )
            XCTAssertNotNil(session.displayPlatform, "Expected inferred platform for \(name)")
        }

        // Test deviceInfo only with inferred patterns
        let deviceInfos = [
            "Random iOS 17.0",
            "Random iPadOS 16.0",
            "Random macOS Sonoma",
            "Random Android 13",
            "Random Windows 10"
        ]
        for info in deviceInfos {
            let session = UserSession(
                id: UUID(),
                deviceInfo: info,
                deviceName: nil,
                createdAt: now,
                expiresAt: now.addingTimeInterval(3600),
                isCurrent: false
            )
            XCTAssertNotNil(session.displayPlatform)
        }
    }


    // MARK: - NotificationDestination Dictionary & AnyHashable Parsing
    func testNotificationDestinationDictionaryParsing() {
        let convId = UUID()
        let anyHashableDict: [AnyHashable: Any] = [
            "destination": [
                (AnyHashable("destinationScreen")): "MESSAGES",
                (AnyHashable("conversationId")): convId.uuidString
            ]
        ]
        let dest = NotificationDestination.fromPushUserInfo(anyHashableDict)
        XCTAssertEqual(dest?.screen, .messages)
        XCTAssertEqual(dest?.conversationId, convId)

        // Directly string-keyed dictionary
        let strKeyed: [String: Any] = [
            "destination": [
                "screen": "POST_DETAIL",
                "destinationPostId": UUID().uuidString,
                "comment_id": UUID().uuidString
            ]
        ]
        let destStr = NotificationDestination.fromPushUserInfo(strKeyed)
        XCTAssertEqual(destStr?.screen, .postDetail)
        XCTAssertNotNil(destStr?.postDetailId)
        XCTAssertNotNil(destStr?.commentId)

        // Type fallback inside dictionary
        let typeKeyed: [String: Any] = [
            "destination": [
                "type": "DIRECT_MESSAGE",
                "conversation_id": convId.uuidString
            ]
        ]
        let destType = NotificationDestination.fromPushUserInfo(typeKeyed)
        XCTAssertEqual(destType?.screen, .messages)

        // Non-dictionary, non-json invalid string
        let invalidNested: [String: Any] = [
            "destination": 12345
        ]
        XCTAssertNil(NotificationDestination.fromPushUserInfo(invalidNested))

        // Nil raw input
        XCTAssertNil(NotificationDestination.fromPushUserInfo([:]))

        // UUID direct value
        let directUUID = UUID()
        let withDirectUUID: [String: Any] = [
            "screen": "POST_DETAIL",
            "postId": directUUID,
            "commentId": directUUID
        ]
        let destDirect = NotificationDestination.fromPushUserInfo(withDirectUUID)
        XCTAssertEqual(destDirect?.postId, directUUID)
        XCTAssertEqual(destDirect?.commentId, directUUID)

        // SpendingTrendPoint.id
        let now = Date()
        let trendPoint = SpendingTrendPoint(bucketStart: now, amount: 50_000)
        XCTAssertEqual(trendPoint.id, now)

        // PostAudience with unsorted multiple IDs triggering sorting closure
        let u1 = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        let u2 = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        let audMulti = PostAudience(mode: .specificUsers, allowedUserIds: [u1, u2])
        XCTAssertEqual(audMulti.allowedUserIds, [u2, u1])

        let audExceptMulti = PostAudience(mode: .friendsExcept, excludedUserIds: [u1, u2])
        XCTAssertEqual(audExceptMulti.excludedUserIds, [u2, u1])

        let audGroupsMulti = PostAudience(mode: .groups, allowedGroupIds: [u1, u2])
        XCTAssertEqual(audGroupsMulti.allowedGroupIds, [u2, u1])
    }
}



