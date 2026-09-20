import XCTest
import SplickDomain
@testable import Common

final class CommonCoreExtensionsAndLogicTests: XCTestCase {

    // MARK: - CommentAttachmentValidator Tests

    func testCommentAttachmentValidator_countsAndSizes() {
        // Valid attachments
        let validImage = CommentAttachment(kind: .image, fileName: "test.jpg", sizeBytes: 1024)
        let validFile = CommentAttachment(kind: .file, fileName: "doc.pdf", sizeBytes: 1024)
        let validVideo = CommentAttachment(kind: .video, fileName: "clip.mp4", sizeBytes: 1024)
        let validGif = CommentAttachment(kind: .gif, fileName: "fun.gif", sizeBytes: 1024)

        XCTAssertNil(CommentAttachmentValidator.validate([validImage, validFile, validVideo, validGif]))

        // Exceed images count (max 5)
        let sixImages = (0..<6).map { CommentAttachment(kind: .image, fileName: "\($0).jpg", sizeBytes: 100) }
        XCTAssertNotNil(CommentAttachmentValidator.validate(sixImages))

        // Exceed files count (max 10)
        let elevenFiles = (0..<11).map { CommentAttachment(kind: .file, fileName: "\($0).pdf", sizeBytes: 100) }
        XCTAssertNotNil(CommentAttachmentValidator.validate(elevenFiles))

        // Exceed videos count (max 3)
        let fourVideos = (0..<4).map { CommentAttachment(kind: .video, fileName: "\($0).mp4", sizeBytes: 100) }
        XCTAssertNotNil(CommentAttachmentValidator.validate(fourVideos))

        // Exceed gifs count (max 1)
        let twoGifs = (0..<2).map { CommentAttachment(kind: .gif, fileName: "\($0).gif", sizeBytes: 100) }
        XCTAssertNotNil(CommentAttachmentValidator.validate(twoGifs))

        // Exceed file bytes (max 10MB)
        let hugeFile = CommentAttachment(kind: .file, fileName: "big.zip", sizeBytes: 11 * 1024 * 1024)
        XCTAssertNotNil(CommentAttachmentValidator.validate([hugeFile]))

        // Exceed video bytes (max 100MB)
        let hugeVideo = CommentAttachment(kind: .video, fileName: "movie.mp4", sizeBytes: 101 * 1024 * 1024)
        XCTAssertNotNil(CommentAttachmentValidator.validate([hugeVideo]))

        // canAdd helper
        XCTAssertNil(CommentAttachmentValidator.canAdd(validImage, to: []))
        let threeVideos = (0..<3).map { CommentAttachment(kind: .video, fileName: "\($0).mp4", sizeBytes: 100) }
        XCTAssertNotNil(CommentAttachmentValidator.canAdd(validVideo, to: threeVideos))

        // previewModels
        let submission1 = CommentSubmissionAttachment(kind: .image, data: Data(repeating: 0, count: 500), mimeType: "image/jpeg", fileName: "pic.jpg")
        let submission2 = CommentSubmissionAttachment(kind: .file, uploadedMediaId: UUID(), url: URL(string: "https://example.com/doc.txt")!, sizeBytes: 2048, fileName: "doc.txt")
        let previews = CommentAttachmentValidator.previewModels(from: [submission1, submission2])
        XCTAssertEqual(previews.count, 2)
        XCTAssertEqual(previews[0].sizeBytes, 500)
        XCTAssertEqual(previews[1].sizeBytes, 2048)
    }

    // MARK: - SplickMoneyFormat Tests

    func testSplickMoneyFormat_formatting() {
        XCTAssertEqual(SplickMoneyFormat.string(from: Decimal(1250000)), "1,250,000")
        XCTAssertEqual(SplickMoneyFormat.string(from: Decimal(0)), "0")
        XCTAssertEqual(SplickMoneyFormat.string(from: Decimal(string: "1234.56")!, maxFractionDigits: 2), "1,234.56")
        XCTAssertEqual(SplickMoneyFormat.string(from: Decimal(string: "1234.50")!, maxFractionDigits: 2), "1,234.5")
    }

    // MARK: - DecimalCompactCurrency Tests

    func testDecimalCompactCurrency_compactAndChartStrings() {
        // Compact amounts
        XCTAssertEqual(Decimal(500).compactAmountString(), "500")
        XCTAssertEqual(Decimal(1500).compactAmountString(), "1.5K")
        XCTAssertEqual(Decimal(125000).compactAmountString(), "125K")
        XCTAssertEqual(Decimal(1500000).compactAmountString(), "1.5M")
        XCTAssertEqual(Decimal(200000000).compactAmountString(), "200M")
        XCTAssertEqual(Decimal(-75000).compactAmountString(), "-75K")

        // Currency symbol
        XCTAssertEqual(Decimal.displayCurrencySymbol(for: "VND"), "đ")
        XCTAssertEqual(Decimal.displayCurrencySymbol(for: "USD"), "$")
        XCTAssertFalse(Decimal.displayCurrencySymbol(for: "EUR").isEmpty)

        // Chart amounts
        let vndChart = Decimal(1250000).chartAmountString(currencyCode: "VND")
        XCTAssertTrue(vndChart.contains("1,250,000"))
        XCTAssertTrue(vndChart.contains("đ"))

        let usdChart = Decimal(1250).chartAmountString(currencyCode: "USD")
        XCTAssertTrue(usdChart.hasPrefix("$"))
        XCTAssertTrue(usdChart.contains("1,250"))

        let hugeAmount = Decimal(string: "9999999999999")!.chartAmountString(currencyCode: "VND")
        XCTAssertTrue(hugeAmount.contains("M") || hugeAmount.contains("K"))
    }

    // MARK: - StringExtensions Tests

    func testStringExtensions_validationAndHelpers() {
        // Email
        XCTAssertTrue("user@example.com".isValidEmail)
        XCTAssertTrue("first.last+tag@sub.domain.co".isValidEmail)
        XCTAssertFalse("invalid-email".isValidEmail)
        XCTAssertFalse("@missinguser.com".isValidEmail)
        XCTAssertFalse("missingdomain@".isValidEmail)

        // Username
        XCTAssertTrue("hoan_03".isValidUsername)
        XCTAssertTrue("john.doe123".isValidUsername)
        XCTAssertFalse("invalid user".isValidUsername)
        XCTAssertFalse("user@name".isValidUsername)

        // Suggested username from email
        XCTAssertEqual("hoan.dev@gmail.com".suggestedUsernameFromEmail, "hoan.dev")
        XCTAssertEqual("user+tag@domain.com".suggestedUsernameFromEmail, "user_tag")
        XCTAssertEqual("ab@domain.com".suggestedUsernameFromEmail, "") // < 3 chars
        XCTAssertEqual("invalid_email".suggestedUsernameFromEmail, "")

        // E164 phone
        XCTAssertTrue("+84901234567".isValidE164Phone)
        XCTAssertTrue("84901234567".isValidE164Phone)
        XCTAssertFalse("123".isValidE164Phone)

        // Normalized phone
        XCTAssertEqual("0901234567".normalizedE164Phone, "+84901234567")

        // Whitespace and truncation
        XCTAssertEqual("  hello world  \n".trimmed, "hello world")
        XCTAssertTrue("   \t\n".isBlank)
        XCTAssertFalse("  content  ".isBlank)
        XCTAssertEqual("Long text message".truncated(to: 4), "Long...")
        XCTAssertEqual("Short".truncated(to: 10), "Short")

        // Given name only
        XCTAssertEqual("Trần Quốc Hoàn".givenNameOnly, "Hoàn")
        XCTAssertEqual("John Doe".givenNameOnly, "John")
        XCTAssertEqual("Alice".givenNameOnly, "Alice")
        XCTAssertEqual("".givenNameOnly, "")
    }

    // MARK: - DateExtensions Tests

    func testDateExtensions_formatsAndRelative() {
        let date = Date(timeIntervalSince1970: 1768800000) // 2026-01-19
        let iso = date.iso8601String
        XCTAssertNotNil(Date.from(iso8601: iso))

        let calendarStr = date.apiCalendarDateString
        XCTAssertNotNil(Date.from(apiCalendarDate: calendarStr))

        // Relative formatting
        SplickRelativeDateFormatters.apply(locale: Locale(identifier: "en_US"))
        let now = Date()
        let past = now.addingTimeInterval(-3600)
        XCTAssertFalse(past.relativeString.isEmpty)
        XCTAssertFalse(past.expenseListRelativeString.isEmpty)

        // Today / Yesterday
        XCTAssertTrue(now.isToday)
        XCTAssertFalse(now.isYesterday)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        XCTAssertTrue(yesterday.isYesterday)
        XCTAssertFalse(yesterday.isToday)
    }

    // MARK: - Error Formatting & AppError Tests

    func testAppError_and_SplickErrorFormatting() {
        // AppError userMessages
        let netErr = AppError.network(.noConnection)
        XCTAssertTrue(netErr.userMessage.contains("offline"))

        let storeErr = AppError.storage(.fetchFailed("disk error"))
        XCTAssertFalse(storeErr.userMessage.isEmpty)

        let valErr = AppError.validation("Invalid value")
        XCTAssertEqual(valErr.userMessage, "Invalid value")

        let unknownErr = AppError.unknown("Something broke")
        XCTAssertEqual(unknownErr.userMessage, "Something broke")

        // NetworkError helpers
        let timeout = NetworkError.timeout
        XCTAssertTrue(timeout.isConnectivityIssue)
        XCTAssertTrue(timeout.shouldKeepLocalSession)

        let unauth = NetworkError.unauthorized
        XCTAssertFalse(unauth.isConnectivityIssue)
        XCTAssertFalse(unauth.shouldKeepLocalSession)

        let serverErrWithTrace = NetworkError.serverError(statusCode: 500, traceId: "trace-12345")
        XCTAssertEqual(serverErrWithTrace.supportTraceId, "trace-12345")

        // SplickErrorFormatting
        XCTAssertEqual(SplickErrorFormatting.supportTraceId(for: serverErrWithTrace), "trace-12345")
        XCTAssertEqual(SplickErrorFormatting.supportTraceId(for: AppError.network(serverErrWithTrace)), "trace-12345")
        XCTAssertNil(SplickErrorFormatting.supportTraceId(for: NSError(domain: "d", code: 1)))

        let msg = SplickErrorFormatting.userMessage(for: serverErrWithTrace)
        XCTAssertFalse(msg.isEmpty)

        let withRef = SplickErrorFormatting.appendSupportReference(to: "Failed", traceId: "TR-999")
        XCTAssertTrue(withRef.contains("Reference: TR-999"))
        XCTAssertEqual(SplickErrorFormatting.appendSupportReference(to: "Failed", traceId: nil), "Failed")

        // Request Cancellation
        XCTAssertTrue(CancellationError().isRequestCancellation)
        XCTAssertTrue(URLError(.cancelled).isRequestCancellation)
        XCTAssertTrue(NetworkError.unknown("Request was cancelled").isRequestCancellation)
        XCTAssertFalse(URLError(.badURL).isRequestCancellation)
    }

    // MARK: - CustomEmojiStore Tests

    @MainActor
    func testCustomEmojiStore_crudAndLoad() async {
        let store = CustomEmojiStore()
        let user1 = UUID()
        let user2 = UUID()

        let emoji1 = CustomEmoji(id: UUID(), ownerId: nil, shortcode: "smile", mediaUrl: URL(string: "https://example.com/smile.png")!)
        let emoji2 = CustomEmoji(id: UUID(), ownerId: user1, shortcode: "heart", mediaUrl: URL(string: "https://example.com/heart.png")!)
        let emoji3 = CustomEmoji(id: UUID(), ownerId: user2, shortcode: "fire", mediaUrl: URL(string: "https://example.com/fire.png")!)

        store.applyStartupEmojis([emoji1, emoji2])
        XCTAssertEqual(store.allEmojis.count, 2)

        // emojis(ownedBy:)
        let user1Emojis = store.emojis(ownedBy: user1)
        XCTAssertEqual(user1Emojis.count, 2) // global + user1
        let user2Emojis = store.emojis(ownedBy: user2)
        XCTAssertEqual(user2Emojis.count, 1) // only global

        // resolve(shortcode:)
        XCTAssertEqual(store.resolve(shortcode: "smile"), emoji1.mediaUrl)
        XCTAssertNil(store.resolve(shortcode: "unknown"))

        // upsert new
        store.upsert(emoji3)
        XCTAssertEqual(store.allEmojis.count, 3)

        // upsert existing
        let updatedEmoji1 = CustomEmoji(id: emoji1.id, ownerId: nil, shortcode: "smile_v2", mediaUrl: emoji1.mediaUrl)
        store.upsert(updatedEmoji1)
        XCTAssertEqual(store.allEmojis.count, 3)
        XCTAssertEqual(store.resolve(shortcode: "smile_v2"), emoji1.mediaUrl)

        // remove
        store.remove(emojiId: emoji3.id)
        XCTAssertEqual(store.allEmojis.count, 2)

        // load & reload with fetcher
        struct MockEmojiFetcher: CustomEmojiFetching {
            let result: [CustomEmoji]
            func fetchAllEmojis() async throws -> [CustomEmoji] { result }
            func fetchMyEmojis() async throws -> [CustomEmoji] { result }
            func addEmoji(alias: String?, mediaId: UUID) async throws -> CustomEmoji {
                CustomEmoji(id: UUID(), ownerId: nil, shortcode: alias ?? "added", mediaUrl: URL(string: "https://example.com")!)
            }
            func deleteEmoji(emojiId: UUID) async throws {}
        }

        let fetchedEmoji = CustomEmoji(id: UUID(), ownerId: nil, shortcode: "star", mediaUrl: URL(string: "https://example.com/star.png")!)
        let fetcher = MockEmojiFetcher(result: [fetchedEmoji])

        await store.load(fetcher: fetcher)
        XCTAssertTrue(store.allEmojis.contains(where: { $0.shortcode == "star" }))

        await store.reload(fetcher: fetcher)
        XCTAssertTrue(store.allEmojis.contains(where: { $0.shortcode == "star" }))
    }

    // MARK: - DeletedUser & Notification Tests

    func testDeletedUser_and_Notifications() {
        XCTAssertTrue(DeletedUser.isDeleted(displayName: "Deleted User"))
        XCTAssertFalse(DeletedUser.isDeleted(displayName: "Active User"))

        XCTAssertEqual(Notification.Name.expensesDirectoryDidChange, ExpensesDirectoryChange.notification)
        XCTAssertEqual(Notification.Name.paymentEvidenceStatusDidChange, ExpensesDirectoryChange.notification)

        XCTAssertEqual(AppNotificationSound.resolved("custom").rawValue, "default")
        XCTAssertFalse(AppNotificationSound.default.isSilent)
        XCTAssertEqual(AppNotificationSound.loadFromAppGroup(), .default)
    }
}
