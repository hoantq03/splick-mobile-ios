import XCTest
@testable import SplickWidgetKit

final class WidgetFormattersAndModelsTests: XCTestCase {
    // MARK: - WidgetCurrencyFormatter

    func testWidgetCurrencyFormatterVND() {
        let formatted = WidgetCurrencyFormatter.string(from: Decimal(100000), currency: "VND")
        XCTAssertEqual(formatted, "100,000₫")

        let positive = WidgetCurrencyFormatter.signedString(from: Decimal(50000), currency: "VND")
        XCTAssertEqual(positive, "+50,000₫")

        let negative = WidgetCurrencyFormatter.signedString(from: Decimal(-50000), currency: "VND")
        XCTAssertEqual(negative, "-50,000₫")

        let zero = WidgetCurrencyFormatter.signedString(from: Decimal(0), currency: "VND")
        XCTAssertEqual(zero, "0₫")
    }

    func testWidgetCurrencyFormatterUSD() {
        let formatted = WidgetCurrencyFormatter.string(from: Decimal(string: "25.50")!, currency: "USD")
        XCTAssertEqual(formatted, "$25.50")

        let positive = WidgetCurrencyFormatter.signedString(from: Decimal(string: "12.34")!, currency: "USD")
        XCTAssertEqual(positive, "+$12.34")

        let negative = WidgetCurrencyFormatter.signedString(from: Decimal(string: "-12.34")!, currency: "USD")
        XCTAssertEqual(negative, "-$12.34")

        let zero = WidgetCurrencyFormatter.signedString(from: .zero, currency: "USD")
        XCTAssertEqual(zero, "$0.00")
    }

    func testWidgetCurrencyFormatterOtherCurrency() {
        let formatted = WidgetCurrencyFormatter.string(from: Decimal(string: "99.99")!, currency: "EUR")
        XCTAssertEqual(formatted, "99.99 EUR")

        let signed = WidgetCurrencyFormatter.signedString(from: Decimal(string: "99.99")!, currency: "EUR")
        XCTAssertEqual(signed, "+99.99 EUR")
    }

    func testWidgetCurrencyFormatterDecimalParsing() {
        XCTAssertEqual(WidgetCurrencyFormatter.decimal(from: "123.45"), Decimal(string: "123.45"))
        XCTAssertEqual(WidgetCurrencyFormatter.decimal(from: "invalid_number"), Decimal.zero)
    }

    // MARK: - WidgetRelativeDateFormatter

    func testWidgetRelativeDateFormatter() {
        let now = Date()
        let short = WidgetRelativeDateFormatter.shortString(from: now)
        XCTAssertFalse(short.isEmpty)

        let past = now.addingTimeInterval(-3600)
        let pastShort = WidgetRelativeDateFormatter.shortString(from: past)
        XCTAssertFalse(pastShort.isEmpty)
    }

    // MARK: - HomeScreenWidget

    func testHomeScreenWidgetCases() {
        for widget in HomeScreenWidget.allCases {
            XCTAssertEqual(widget.id, widget.kind)
            XCTAssertFalse(widget.kind.isEmpty)
            XCTAssertFalse(widget.systemImage.isEmpty)
        }

        XCTAssertEqual(HomeScreenWidget.expenseSummary.kind, WidgetKind.expenseSummary)
        XCTAssertEqual(HomeScreenWidget.expenseSummary.systemImage, "banknote")

        XCTAssertEqual(HomeScreenWidget.unreadMessages.kind, WidgetKind.unreadMessages)
        XCTAssertEqual(HomeScreenWidget.unreadMessages.systemImage, "message.fill")

        XCTAssertEqual(HomeScreenWidget.latestFriendPhoto.kind, WidgetKind.latestFriendPhoto)
        XCTAssertEqual(HomeScreenWidget.latestFriendPhoto.systemImage, "photo.on.rectangle.angled")

        XCTAssertEqual(HomeScreenWidget.friendStreak.kind, WidgetKind.friendStreak)
        XCTAssertEqual(HomeScreenWidget.friendStreak.systemImage, "flame.fill")

        XCTAssertEqual(HomeScreenWidget.quickCapture.kind, WidgetKind.quickCapture)
        XCTAssertEqual(HomeScreenWidget.quickCapture.systemImage, "camera.fill")

        XCTAssertEqual(HomeScreenWidget.friendRequest.kind, WidgetKind.friendRequest)
        XCTAssertEqual(HomeScreenWidget.friendRequest.systemImage, "person.badge.plus")

        XCTAssertEqual(HomeScreenWidget.groupExpense.kind, WidgetKind.groupExpense)
        XCTAssertEqual(HomeScreenWidget.groupExpense.systemImage, "person.3.fill")
    }

    // MARK: - AppGroupConstants

    func testAppGroupConstants() {
        XCTAssertEqual(WidgetAppGroup.identifier, "group.com.splick.app")
        XCTAssertNotNil(WidgetAppGroup.containerURL)
        XCTAssertNotNil(WidgetAppGroup.cacheDirectoryURL)
        XCTAssertNotNil(WidgetAppGroup.imageCacheDirectoryURL)

        XCTAssertEqual(WidgetCacheFile.expenseSummary, "expense_summary.json")
        XCTAssertEqual(WidgetCacheFile.messagingInbox, "messaging_inbox.json")
        XCTAssertEqual(WidgetCacheFile.latestFriendPhoto, "latest_friend_photo.json")
        XCTAssertEqual(WidgetCacheFile.streak, "streak.json")
        XCTAssertEqual(WidgetCacheFile.friendRequests, "friend_requests.json")
        XCTAssertEqual(WidgetCacheFile.groups, "groups.json")

        let testId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        XCTAssertEqual(WidgetCacheFile.groupExpense(groupId: testId), "group_expense_11111111-2222-3333-4444-555555555555.json")

        XCTAssertEqual(WidgetKind.expenseSummary, "ExpenseSummaryWidget")
        XCTAssertEqual(WidgetKind.unreadMessages, "UnreadMessagesWidget")
        XCTAssertEqual(WidgetKind.latestFriendPhoto, "LatestFriendPhotoWidget")
        XCTAssertEqual(WidgetKind.friendStreak, "FriendStreakWidget")
        XCTAssertEqual(WidgetKind.quickCapture, "QuickCaptureWidget")
        XCTAssertEqual(WidgetKind.friendRequest, "FriendRequestWidget")
        XCTAssertEqual(WidgetKind.groupExpense, "GroupExpenseWidget")
    }

    // MARK: - Snapshot Models Codable & Equatable

    func testWidgetSnapshotModelsEncodingDecoding() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

        // WidgetDebtItem
        let debtItem = WidgetDebtItem(
            userId: UUID(),
            displayName: "Alice",
            amount: "50,000₫",
            currency: "VND",
            isOwed: false
        )
        let debtData = try encoder.encode(debtItem)
        let decodedDebt = try decoder.decode(WidgetDebtItem.self, from: debtData)
        XCTAssertEqual(debtItem, decodedDebt)

        // WidgetExpenseSummarySnapshot
        let expenseSnapshot = WidgetExpenseSummarySnapshot(
            netAmount: "+50,000₫",
            currency: "VND",
            totalOwing: "10,000₫",
            totalOwed: "60,000₫",
            owingPeopleCount: 1,
            owedPeopleCount: 2,
            topDebts: [debtItem],
            updatedAt: fixedDate
        )
        let expData = try encoder.encode(expenseSnapshot)
        let decodedExp = try decoder.decode(WidgetExpenseSummarySnapshot.self, from: expData)
        XCTAssertEqual(expenseSnapshot, decodedExp)

        // WidgetConversationPreview & WidgetMessagingInboxSnapshot
        let convPreview = WidgetConversationPreview(
            id: UUID(),
            displayTitle: "Chat Group",
            previewText: "Hello!",
            unreadCount: 3,
            avatarURL: "https://example.com/avatar.jpg",
            updatedAt: fixedDate
        )
        let inboxSnapshot = WidgetMessagingInboxSnapshot(
            totalUnreadCount: 3,
            conversations: [convPreview],
            updatedAt: fixedDate
        )
        let inboxData = try encoder.encode(inboxSnapshot)
        let decodedInbox = try decoder.decode(WidgetMessagingInboxSnapshot.self, from: inboxData)
        XCTAssertEqual(inboxSnapshot, decodedInbox)

        // WidgetLatestFriendPhotoSnapshot
        let photoSnapshot = WidgetLatestFriendPhotoSnapshot(
            postId: UUID(),
            authorName: "Bob",
            authorUsername: "bob99",
            reactionCount: 12,
            createdAt: fixedDate,
            cachedImageFilename: "post_123.jpg",
            remoteImageURL: "https://example.com/photo.jpg"
        )
        let photoData = try encoder.encode(photoSnapshot)
        let decodedPhoto = try decoder.decode(WidgetLatestFriendPhotoSnapshot.self, from: photoData)
        XCTAssertEqual(photoSnapshot, decodedPhoto)

        // WidgetStreakSnapshot
        let streakSnapshot = WidgetStreakSnapshot(
            currentStreak: 7,
            hasTodayPhoto: true,
            updatedAt: fixedDate
        )
        let streakData = try encoder.encode(streakSnapshot)
        let decodedStreak = try decoder.decode(WidgetStreakSnapshot.self, from: streakData)
        XCTAssertEqual(streakSnapshot, decodedStreak)

        // WidgetFriendRequestPreview & WidgetFriendRequestsSnapshot
        let requestPreview = WidgetFriendRequestPreview(
            id: UUID(),
            requesterName: "Charlie",
            requesterUsername: "charlie_x",
            avatarURL: nil,
            createdAt: fixedDate
        )
        let requestSnapshot = WidgetFriendRequestsSnapshot(
            pendingCount: 1,
            requests: [requestPreview],
            updatedAt: fixedDate
        )
        let reqData = try encoder.encode(requestSnapshot)
        let decodedReq = try decoder.decode(WidgetFriendRequestsSnapshot.self, from: reqData)
        XCTAssertEqual(requestSnapshot, decodedReq)

        // WidgetGroupOption & WidgetGroupsSnapshot
        let groupOption = WidgetGroupOption(
            id: UUID(),
            name: "Roommates",
            memberCount: 4
        )
        XCTAssertEqual(groupOption.id, groupOption.id)
        let groupsSnapshot = WidgetGroupsSnapshot(
            groups: [groupOption],
            updatedAt: fixedDate
        )
        let groupsData = try encoder.encode(groupsSnapshot)
        let decodedGroups = try decoder.decode(WidgetGroupsSnapshot.self, from: groupsData)
        XCTAssertEqual(groupsSnapshot, decodedGroups)

        // WidgetGroupMemberBalance & WidgetGroupExpenseSnapshot
        let memberBalance = WidgetGroupMemberBalance(
            userId: UUID(),
            displayName: "Dave",
            amount: "25,000₫",
            isOwed: true
        )
        let groupExpSnapshot = WidgetGroupExpenseSnapshot(
            groupId: UUID(),
            groupName: "Vacation Trip",
            totalAmount: "500,000₫",
            settledPercentage: 50,
            currency: "VND",
            memberBalances: [memberBalance],
            updatedAt: fixedDate
        )
        let groupExpData = try encoder.encode(groupExpSnapshot)
        let decodedGroupExp = try decoder.decode(WidgetGroupExpenseSnapshot.self, from: groupExpData)
        XCTAssertEqual(groupExpSnapshot, decodedGroupExp)
    }
}
