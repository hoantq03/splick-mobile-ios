import XCTest
import SplickDomain
import Common
import FeatureSocialFeed
import FeatureExpense
import FeatureNotification
import FeatureMedia
import FeatureFriends
import FeatureMessaging
@testable import SimulationKit

final class SimulationFakesTests: XCTestCase {

    // MARK: - FakeMediaRepository Tests

    func testFakeMediaRepository() async throws {
        let repo = FakeMediaRepository()
        let data = Data([0x01, 0x02, 0x03])

        // User avatar
        let userResult = try await repo.uploadImage(
            data: data,
            mimeType: "image/jpeg",
            purpose: .userAvatar,
            groupId: nil
        )
        XCTAssertEqual(userResult.sizeBytes, 3)
        XCTAssertTrue(userResult.url.absoluteString.contains("users"))

        // Group avatar
        let gId = UUID()
        let groupResult = try await repo.uploadImage(
            data: data,
            mimeType: "image/png",
            purpose: .groupAvatar,
            groupId: gId
        )
        XCTAssertTrue(groupResult.url.absoluteString.contains("groups/\(gId.uuidString)"))

        // Delete
        try await repo.deleteMedia(id: userResult.id)
    }

    // MARK: - FakeFeedRepository Tests

    func testFakeFeedRepositoryLifecycle() async throws {
        let logger = StateLogger(module: "FeedTest", printToConsole: false)
        let repo = FakeFeedRepository(logger: logger)

        await repo.seed()

        // Fetch feed
        let feed = try await repo.fetchFeed(page: 0, limit: 10, authorId: nil)
        XCTAssertFalse(feed.isEmpty)

        // Count posts ahead
        let ahead = try await repo.countFeedPostsAhead(afterCreatedAt: Date(), afterId: UUID())
        XCTAssertEqual(ahead, 0)

        // Fetch single post
        let firstPost = feed[0]
        let post = try await repo.fetchPost(id: firstPost.id)
        XCTAssertEqual(post.id, firstPost.id)

        // Fetch non-existent post throws notFound
        do {
            _ = try await repo.fetchPost(id: UUID())
            XCTFail("Expected notFound")
        } catch NetworkError.notFound {
            // expected
        }

        // Comments & Reactions
        let commentsPage = try await repo.fetchPostComments(
            postId: firstPost.id,
            page: 0,
            limit: 10,
            filter: .all
        )
        XCTAssertNotNil(commentsPage)

        let reactions = try await repo.fetchPostReactions(postId: firstPost.id)
        XCTAssertNotNil(reactions)

        // Record views
        let viewed = try await repo.recordPostViews(postIds: [firstPost.id])
        XCTAssertEqual(viewed.count, 1)

        // Caching
        _ = await repo.loadCachedFeed(userId: UUID())
        await repo.saveCachedFeed(feed, userId: UUID())

        // Add & remove reaction
        let reaction = try await repo.addReaction(postId: firstPost.id, emoji: "🔥")
        XCTAssertEqual(reaction.emoji, "🔥")
        try await repo.removeReaction(postId: firstPost.id, reactionId: reaction.id)

        // Add comment
        try await repo.addComment(
            postId: firstPost.id,
            body: "Great post!",
            parentCommentId: nil,
            submissionAttachments: []
        )

        // Update post & edits
        let updateInput = UpdatePostInput(
            postId: firstPost.id,
            caption: "Updated caption",
            mediaItems: []
        )
        let updatedPost = try await repo.updatePost(updateInput)
        XCTAssertEqual(updatedPost.caption, "Updated caption")

        let edits = try await repo.fetchPostEdits(postId: firstPost.id)
        XCTAssertEqual(edits.count, 1)

        // Create post
        let createInput = CreatePostInput(
            mediaItems: [
                CreatePostMediaInput(data: Data([0x01]), mimeType: "image/jpeg", mediaType: .image)
            ],
            caption: "New post",
            companionIds: [],
            feedKind: .checkIn,
            audience: .friends
        )
        let createdPost = try await repo.createPost(createInput)
        XCTAssertEqual(createdPost.caption, "New post")

        // Delete post
        try await repo.deletePost(id: createdPost.id)

        // Bill reminder
        _ = try await repo.sendBillReminder(
            postId: firstPost.id,
            targetUserIds: nil,
            message: "Please pay!",
            submissionAttachments: []
        )

        // Payment evidence
        let submitResult = try await repo.submitPaymentEvidence(
            postId: firstPost.id,
            splitId: UUID(),
            message: "Paid via bank",
            submissionAttachments: []
        )
        try await repo.approvePaymentEvidence(postId: firstPost.id, evidenceId: submitResult.evidenceId)
        try await repo.rejectPaymentEvidence(postId: firstPost.id, evidenceId: submitResult.evidenceId, reason: "Invalid")

        // Streaks
        let streakSummary = try await repo.fetchStreakSummary()
        XCTAssertNotNil(streakSummary)

        let calendar = try await repo.fetchStreakCalendar(year: 2026, month: 9)
        XCTAssertNotNil(calendar)

        let photos = try await repo.fetchStreakDayPhotos(date: "2026-09-20")
        XCTAssertNotNil(photos)

        // Locations
        let searched = try await repo.searchLocations(query: "Saigon", lat: 10.0, lon: 106.0)
        XCTAssertEqual(searched.count, 1)

        let nearby = try await repo.nearbyLocations(lat: 10.0, lon: 106.0, radiusMeters: 500)
        XCTAssertEqual(nearby.count, 1)

        // Photo album
        let albumPage = try await repo.fetchPhotoAlbumFirstPage(limit: 5)
        XCTAssertNotNil(albumPage)
        if let cursor = albumPage.nextCursor {
            let nextPage = try await repo.fetchPhotoAlbumNextPage(
                limit: 5,
                filters: PhotoAlbumFilters(),
                cursor: cursor
            )
            XCTAssertNotNil(nextPage)
        }
    }

    // MARK: - FakeFriendsRepository Tests

    func testFakeFriendsRepositoryLifecycle() async throws {
        let logger = StateLogger(module: "FriendsTest", printToConsole: false)
        let repo = FakeFriendsRepository(logger: logger)

        await repo.seed()

        _ = try await repo.fetchFriends(query: "test", page: 0, limit: 10)
        _ = try await repo.fetchMyFriends()
        _ = try await repo.fetchMyFriendsPage(page: 0, size: 20)
        _ = await repo.loadCachedFriends(userId: UUID())
        await repo.saveCachedFriends([], userId: UUID())
        await repo.invalidateCachedFriends(userId: UUID())

        _ = try await repo.searchUsers(query: "john", page: 0, size: 10)
        let pref = try await repo.discoveryPreference()
        XCTAssertFalse(pref)
        let updatedPref = try await repo.updateDiscoveryPreference(nearbyEnabled: true)
        XCTAssertTrue(updatedPref)
        _ = try await repo.findNearbyUsers(lat: 10.0, lon: 106.0)
        try await repo.leaveNearbySession()

        // Groups
        let groups = try await repo.fetchMyGroups()
        XCTAssertEqual(groups.count, 1)

        let group = try await repo.fetchGroup(groupId: groups[0].id)
        XCTAssertEqual(group.id, groups[0].id)

        let created = try await repo.createGroup(name: "New Group", description: "Desc")
        XCTAssertEqual(created.name, "New Group")

        let updated = try await repo.updateGroup(groupId: created.id, name: "Renamed", description: "Updated")
        XCTAssertEqual(updated.name, "Renamed")

        try await repo.leaveGroup(groupId: groups[0].id)
        let joined = try await repo.joinGroup(inviteCode: "roommates-q7")
        XCTAssertEqual(joined.inviteCode, "roommates-q7")

        _ = try await repo.fetchGroupMembers(groupId: created.id, status: nil)
        _ = try await repo.generateGroupQr(groupId: created.id, ttlSeconds: 3600)
        try await repo.revokeGroupQr(groupId: created.id, qrId: UUID())
        try await repo.revokeInviteCode(groupId: created.id, invitationId: UUID())
        try await repo.approvePendingMember(groupId: created.id, memberRowId: UUID())
        try await repo.rejectPendingMember(groupId: created.id, memberRowId: UUID())
        try await repo.removeMember(groupId: created.id, memberRowId: UUID())
        _ = try await repo.transferOwnership(groupId: created.id, newOwnerId: UUID())
        _ = try await repo.fetchActiveInviteCode(groupId: created.id)
        _ = try await repo.updateGroupAvatar(groupId: created.id, avatarURL: "https://example.com/avatar.jpg")

        _ = try? await repo.fetchUserProfile(userId: UUID())
        _ = try? await repo.fetchFriendPaymentProfile(userId: UUID())
        _ = try await repo.searchUser(username: "john")
        _ = try? await repo.addFriend(username: "john", message: nil)
        _ = try await repo.fetchIncomingFriendRequests(page: 0, size: 10)
        _ = try await repo.fetchAllIncomingFriendRequests()
        _ = try? await repo.acceptFriendRequest(requestId: UUID())
        _ = try? await repo.rejectFriendRequest(requestId: UUID())
        _ = try? await repo.cancelFriendRequest(requestId: UUID())
        _ = try await repo.fetchOutgoingFriendRequests(page: 0, size: 10)
        _ = try await repo.fetchAllOutgoingFriendRequests()
        _ = try? await repo.removeFriend(friendUserId: UUID())
        _ = try? await repo.setFriendNickname(friendUserId: UUID(), nickname: "buddy")
        _ = try await repo.fetchBlockedUsers(page: 0, size: 10)
        _ = try await repo.fetchAllBlockedUsers()
        _ = try? await repo.blockUser(userId: UUID())
        _ = try? await repo.unblockUser(userId: UUID())
        _ = try? await repo.addFriendFromQRCode("payload")

        try await repo.leaveGroup(groupId: created.id)
        try await repo.deleteGroup(groupId: created.id)
    }

    // MARK: - FakeExpenseRepository Tests

    func testFakeExpenseRepositoryLifecycle() async throws {
        let logger = StateLogger(module: "ExpenseTest", printToConsole: false)
        let repo = FakeExpenseRepository(logger: logger)

        await repo.seed()

        let expenses = try await repo.fetchExpenses(groupId: nil, page: 0, limit: 10, cursor: nil)
        XCTAssertFalse(expenses.isEmpty)

        let first = expenses[0]
        let detail = try await repo.fetchExpense(id: first.id)
        XCTAssertEqual(detail.id, first.id)

        let newExpense = try await repo.createExpense(
            CreateExpenseRequest(
                description: "Coffee",
                totalAmount: 50000,
                currency: "VND",
                groupId: nil,
                category: .food,
                splitType: .equal,
                participants: [UUID(), UUID()]
            )
        )
        XCTAssertEqual(newExpense.description, "Coffee")

        if let splitId = first.splits.first?.id {
            try await repo.settleExpense(expenseId: first.id, splitId: splitId)
        }

        let debts = try await repo.fetchDebtSummary(groupId: nil)
        XCTAssertNotNil(debts)

        let monthly = try await repo.fetchMonthlySummary(months: 6)
        XCTAssertNotNil(monthly)

        let overview = try await repo.fetchOverview()
        XCTAssertNotNil(overview)

        let analytics = try await repo.fetchSpendingAnalytics(period: .month, months: 3)
        XCTAssertNotNil(analytics)

        let groupSummary = try await repo.fetchGroupExpenseSummary()
        XCTAssertNotNil(groupSummary)

        let expensePage = try await repo.fetchExpenses(
            counterpartyId: UUID(),
            page: 0,
            limit: 10,
            status: .all,
            cursor: nil
        )
        XCTAssertNotNil(expensePage)

        let netting = try await repo.fetchNetting(counterpartyId: UUID())
        XCTAssertNotNil(netting)

        let bulk = try await repo.submitBulkSettlement(
            counterpartyId: UUID(),
            evidenceURL: URL(string: "https://example.com/evidence.png")!,
            note: "settlement"
        )
        let approved = try await repo.approveBulkSettlement(id: bulk.id)
        XCTAssertEqual(approved.id, bulk.id)

        let rejected = try await repo.rejectBulkSettlement(id: bulk.id, reason: "Wrong amount")
        XCTAssertEqual(rejected.id, bulk.id)

        let claim = try await repo.claimBillInvite(token: "invite-tok", splitId: UUID())
        XCTAssertNotNil(claim)
    }

    // MARK: - FakeNotificationRepository Tests

    func testFakeNotificationRepositoryLifecycle() async throws {
        let logger = StateLogger(module: "NotificationTest", printToConsole: false)
        let repo = FakeNotificationRepository(logger: logger)

        await repo.seed()

        let notifications = try await repo.fetchNotifications(page: 0, limit: 10, category: nil)
        XCTAssertFalse(notifications.isEmpty)

        // Categories
        _ = try await repo.fetchNotifications(page: 0, limit: 10, category: "EXPENSES")
        _ = try await repo.fetchNotifications(page: 0, limit: 10, category: "FRIENDS")
        _ = try await repo.fetchNotifications(page: 0, limit: 10, category: "POSTS")
        _ = try await repo.fetchNotifications(page: 5, limit: 10, category: nil)

        let first = notifications[0]
        try await repo.markAsRead(id: first.id)
        try await repo.markAsClicked(id: first.id)
        try await repo.markAllAsRead()
        try await repo.markInboxSeen()

        let count = try await repo.unreadCount()
        XCTAssertNotNil(count)

        let badges = try await repo.fetchBadgeCounts()
        XCTAssertNotNil(badges)

        try await repo.registerDeviceToken(token: "tok-1", bundleId: "com.splick.app", environment: "DEV")
        try await repo.unregisterDeviceToken(token: "tok-1")
    }

    // MARK: - FakeMessagingRepository Tests

    func testFakeMessagingRepositoryLifecycle() async throws {
        let logger = StateLogger(module: "MessagingTest", printToConsole: false)
        let repo = FakeMessagingRepository(logger: logger)

        let page = try await repo.fetchConversations(query: ConversationInboxQuery(page: 0, limit: 10, unreadOnly: false))
        XCTAssertFalse(page.items.isEmpty)

        _ = try await repo.fetchConversations(query: ConversationInboxQuery(page: 1, limit: 10))
        _ = try await repo.fetchConversations(query: ConversationInboxQuery(page: 0, limit: 10, type: .direct, unreadOnly: true))

        let summary = try await repo.fetchConversationInboxSummary()
        XCTAssertGreaterThanOrEqual(summary, 0)

        let firstConvo = page.items[0]
        let convo = try await repo.getOrCreateConversation(friendUserId: firstConvo.peer!.userId)
        XCTAssertEqual(convo.id, firstConvo.id)

        let newConvo = try await repo.getOrCreateConversation(friendUserId: UUID())
        XCTAssertNotNil(newConvo)

        let groupConvo = try await repo.createGroup(name: "Group 1", avatarUrl: nil, memberUserIds: [], groupId: nil)
        XCTAssertEqual(groupConvo.groupName, "Group 1")

        try await repo.addGroupMember(groupId: groupConvo.id, memberUserId: UUID(), shareChatHistory: true)
        _ = try await repo.listGroupMembers(groupId: groupConvo.id)
        try await repo.removeGroupMember(groupId: groupConvo.id, memberUserId: UUID())

        _ = try await repo.renameGroup(groupId: groupConvo.id, name: "Renamed Group")
        _ = try await repo.updateGroupAvatar(groupId: groupConvo.id, avatarUrl: "https://example.com/g.jpg")
        try await repo.transferGroupAdmin(groupId: groupConvo.id, newAdminUserId: UUID())

        try await repo.leaveGroup(groupId: groupConvo.id)
        try await repo.deleteConversation(conversationId: groupConvo.id)

        _ = try await repo.updateNotificationSettings(
            conversationId: firstConvo.id,
            notificationsEnabled: true,
            notificationSound: "default",
            mutedUntil: nil
        )

        // Messages
        let msgPage = try await repo.fetchMessages(
            conversationId: firstConvo.id,
            page: 0,
            limit: 20,
            after: nil,
            before: nil
        )
        XCTAssertFalse(msgPage.items.isEmpty)

        let sentMsg = try await repo.sendMessage(
            conversationId: firstConvo.id,
            body: "Hello",
            clientMessageId: UUID(),
            imageAttachments: []
        )
        XCTAssertEqual(sentMsg.body, "Hello")

        try await repo.markRead(conversationId: firstConvo.id, upToMessageId: sentMsg.id)
        _ = try await repo.unreadCount()

        let reaction = try await repo.addReaction(conversationId: firstConvo.id, messageId: sentMsg.id, emoji: "👍")
        try await repo.removeReaction(conversationId: firstConvo.id, messageId: sentMsg.id, reactionId: reaction.id)

        _ = try await repo.searchMessages(query: "Are", page: 0, limit: 10, conversationId: firstConvo.id)
        let edited = try await repo.editMessage(conversationId: firstConvo.id, messageId: sentMsg.id, body: "Edited body")
        XCTAssertEqual(edited.body, "Edited body")

        try await repo.recallMessage(conversationId: firstConvo.id, messageId: sentMsg.id)
        let ticket = try await repo.requestWsTicket()
        XCTAssertEqual(ticket, "fake-ws-ticket")
    }
}
