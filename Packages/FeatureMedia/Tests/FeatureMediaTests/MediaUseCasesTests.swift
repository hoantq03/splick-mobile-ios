import XCTest
import UIKit
import SplickDomain
import Common
@testable import FeatureMedia

final class MockMediaRepository: MediaRepositoryProtocol, @unchecked Sendable {
    var uploadImageResult: MediaUploadResult?
    var lastUploadData: Data?
    var lastMimeType: String?
    var lastPurpose: MediaUploadPurpose?
    var lastGroupId: UUID?
    var deletedMediaId: UUID?
    var shouldThrow: Error?

    func uploadImage(
        data: Data,
        mimeType: String,
        purpose: MediaUploadPurpose,
        groupId: UUID?
    ) async throws -> MediaUploadResult {
        if let error = shouldThrow {
            throw error
        }
        lastUploadData = data
        lastMimeType = mimeType
        lastPurpose = purpose
        lastGroupId = groupId

        return uploadImageResult ?? MediaUploadResult(
            id: UUID(),
            url: URL(string: "https://cdn.splick.com/test.jpg")!,
            thumbnailURL: URL(string: "https://cdn.splick.com/thumb.jpg"),
            sizeBytes: data.count
        )
    }

    func deleteMedia(id: UUID) async throws {
        if let error = shouldThrow {
            throw error
        }
        deletedMediaId = id
    }
}

final class MediaUseCasesTests: XCTestCase {
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 50, height: 50)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        UIColor.red.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }

    func testUploadUserAvatarUseCaseWithImage() async throws {
        let repo = MockMediaRepository()
        let useCase = UploadUserAvatarUseCase(repository: repo)

        let image = createTestImage()
        let result = try await useCase.execute(image: image)

        XCTAssertEqual(repo.lastPurpose, .userAvatar)
        XCTAssertEqual(repo.lastMimeType, "image/jpeg")
        XCTAssertNil(repo.lastGroupId)
        XCTAssertEqual(result.url.absoluteString, "https://cdn.splick.com/test.jpg")
    }

    func testUploadUserAvatarUseCaseWithDataExceedingLimit() async {
        let repo = MockMediaRepository()
        let useCase = UploadUserAvatarUseCase(repository: repo)

        let hugeData = Data(repeating: 0, count: AppConstants.Media.maxAvatarSizeBytes + 1)
        do {
            _ = try await useCase.execute(imageData: hugeData, mimeType: "image/jpeg")
            XCTFail("Should have thrown size limit error")
        } catch {
            XCTAssertTrue(error is AppError)
        }
    }

    func testUploadGroupAvatarUseCase() async throws {
        let repo = MockMediaRepository()
        let useCase = UploadGroupAvatarUseCase(repository: repo)
        let groupId = UUID()

        let image = createTestImage()
        let result = try await useCase.execute(image: image, groupId: groupId)

        XCTAssertEqual(repo.lastPurpose, .groupAvatar)
        XCTAssertEqual(repo.lastGroupId, groupId)
        XCTAssertEqual(repo.lastMimeType, "image/jpeg")
        XCTAssertNotNil(result.id)

        // Test with raw data exceeding limit
        let hugeData = Data(repeating: 0, count: AppConstants.Media.maxAvatarSizeBytes + 10)
        do {
            _ = try await useCase.execute(imageData: hugeData, groupId: groupId)
            XCTFail("Should have thrown size limit error")
        } catch {
            XCTAssertTrue(error is AppError)
        }
    }

    func testUploadPaymentQrUseCase() async throws {
        let repo = MockMediaRepository()
        let useCase = UploadPaymentQrUseCase(repository: repo)

        let image = createTestImage()
        let result = try await useCase.execute(image: image)

        XCTAssertEqual(repo.lastPurpose, .userPaymentQr)
        XCTAssertNil(repo.lastGroupId)
        XCTAssertEqual(result.url.absoluteString, "https://cdn.splick.com/test.jpg")
    }

    func testUploadMediaUseCase() async throws {
        let repo = MockMediaRepository()
        let useCase = UploadMediaUseCase(repository: repo)
        let groupId = UUID()

        let smallData = Data([0x01, 0x02, 0x03, 0x04])

        // Avatar convenience call
        let result1 = try await useCase.execute(imageData: smallData)
        XCTAssertEqual(repo.lastPurpose, .userAvatar)
        XCTAssertEqual(result1.sizeBytes, 4)

        // Group avatar convenience call
        _ = try await useCase.execute(imageData: smallData, groupId: groupId)
        XCTAssertEqual(repo.lastPurpose, .groupAvatar)
        XCTAssertEqual(repo.lastGroupId, groupId)

        // Custom emoji size limit check
        let emojiDataExceedingLimit = Data(repeating: 0, count: AppConstants.Media.maxCustomEmojiSizeBytes + 1)
        do {
            _ = try await useCase.execute(
                imageData: emojiDataExceedingLimit,
                mimeType: "image/png",
                purpose: .userCustomEmoji,
                groupId: nil
            )
            XCTFail("Should have thrown size limit error for custom emoji")
        } catch {
            XCTAssertTrue(error is AppError)
        }

        // Standard delete call on repository
        let deleteId = UUID()
        try await repo.deleteMedia(id: deleteId)
        XCTAssertEqual(repo.deletedMediaId, deleteId)
    }
}
