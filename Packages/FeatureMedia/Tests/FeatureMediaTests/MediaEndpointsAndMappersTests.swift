import XCTest
import Networking
@testable import FeatureMedia

final class MediaEndpointsAndMappersTests: XCTestCase {
    func testMediaEndpoints() {
        let uploadId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let mediaId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let req = InitiateUploadRequestDTO(
            purpose: "user_avatar",
            contentType: "image/jpeg",
            contentLength: 1024,
            context: UploadContextDTO(groupId: UUID())
        )

        let initiateEndpoint = MediaEndpoint.initiateUpload(req)
        XCTAssertEqual(initiateEndpoint.path, "/v1/media/uploads")
        XCTAssertEqual(initiateEndpoint.method, .post)
        XCTAssertNotNil(initiateEndpoint.body)

        let completeEndpoint = MediaEndpoint.completeUpload(uploadId: uploadId)
        XCTAssertEqual(completeEndpoint.path, "/v1/media/uploads/\(uploadId)/complete")
        XCTAssertEqual(completeEndpoint.method, .post)
        XCTAssertNil(completeEndpoint.body)

        let deleteEndpoint = MediaEndpoint.delete(id: mediaId)
        XCTAssertEqual(deleteEndpoint.path, "/v1/media/\(mediaId)")
        XCTAssertEqual(deleteEndpoint.method, .delete)
        XCTAssertNil(deleteEndpoint.body)
    }

    func testFilterCatalogEndpoint() {
        let endpoint = FilterCatalogEndpoint.list
        XCTAssertEqual(endpoint.path, "/v1/media/filters")
        XCTAssertEqual(endpoint.method, .get)
        XCTAssertNil(endpoint.body)
    }

    func testInitiateUploadRequestDTOEncoding() throws {
        let groupId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let withContext = InitiateUploadRequestDTO(
            purpose: "group_avatar",
            contentType: "image/png",
            contentLength: 2048,
            context: UploadContextDTO(groupId: groupId)
        )
        let dataWithContext = try JSONEncoder().encode(withContext)
        let jsonStrWith = String(data: dataWithContext, encoding: .utf8)!
        XCTAssertTrue(jsonStrWith.contains("group_avatar"))
        XCTAssertTrue(jsonStrWith.contains(groupId.uuidString.lowercased()))

        let withoutContext = InitiateUploadRequestDTO(
            purpose: "user_avatar",
            contentType: "image/jpeg",
            contentLength: 4096,
            context: nil
        )
        let dataWithoutContext = try JSONEncoder().encode(withoutContext)
        let jsonStrWithout = String(data: dataWithoutContext, encoding: .utf8)!
        XCTAssertTrue(jsonStrWithout.contains("user_avatar"))
    }

    func testCompleteUploadRequestDTOEncoding() throws {
        let withEtag = CompleteUploadRequestDTO(etag: "etag-abc-123")
        let dataWith = try JSONEncoder().encode(withEtag)
        XCTAssertTrue(String(data: dataWith, encoding: .utf8)!.contains("etag-abc-123"))

        let withoutEtag = CompleteUploadRequestDTO(etag: nil)
        let dataWithout = try JSONEncoder().encode(withoutEtag)
        XCTAssertTrue(String(data: dataWithout, encoding: .utf8)!.contains("{}"))
    }

    func testDTOJSONDecoding() throws {
        let mediaUploadJSON = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "url": "https://cdn.splick.com/test.jpg",
            "thumbnailUrl": "https://cdn.splick.com/thumb.jpg",
            "sizeBytes": 12345
        }
        """.data(using: .utf8)!
        let mediaUpload = try JSONDecoder().decode(MediaUploadResponseDTO.self, from: mediaUploadJSON)
        XCTAssertEqual(mediaUpload.id.uuidString, "11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(mediaUpload.url, "https://cdn.splick.com/test.jpg")
        XCTAssertEqual(mediaUpload.thumbnailUrl, "https://cdn.splick.com/thumb.jpg")
        XCTAssertEqual(mediaUpload.sizeBytes, 12345)

        let initiateUploadJSON = """
        {
            "uploadId": "22222222-2222-2222-2222-222222222222",
            "presignedUrl": "https://s3.splick.com/upload",
            "requiredHeaders": { "Content-Type": "image/jpeg" },
            "expiresAt": 1726750000
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let initiateUpload = try decoder.decode(InitiateUploadResponseDTO.self, from: initiateUploadJSON)
        XCTAssertEqual(initiateUpload.uploadId.uuidString, "22222222-2222-2222-2222-222222222222")
        XCTAssertEqual(initiateUpload.presignedUrl, "https://s3.splick.com/upload")
        XCTAssertEqual(initiateUpload.requiredHeaders["Content-Type"], "image/jpeg")
    }

    func testFilterCatalogMapper() throws {
        let itemId = UUID()
        let validDTO = FilterCatalogItemDTO(
            id: itemId,
            slug: "warm-vintage",
            name: "Warm Vintage",
            type: "LUT",
            thumbnailUrl: "https://cdn.splick.com/filters/thumb.png",
            assetUrl: "https://cdn.splick.com/filters/warm.cube",
            version: 2,
            minAppVersion: "1.2.0"
        )
        let item = try FilterCatalogMapper.map(validDTO)
        XCTAssertEqual(item.id, itemId)
        XCTAssertEqual(item.slug, "warm-vintage")
        XCTAssertEqual(item.name, "Warm Vintage")
        XCTAssertEqual(item.type, .lut)
        XCTAssertEqual(item.thumbnailURL?.absoluteString, "https://cdn.splick.com/filters/thumb.png")
        XCTAssertEqual(item.assetURL.absoluteString, "https://cdn.splick.com/filters/warm.cube")
        XCTAssertEqual(item.version, 2)
        XCTAssertEqual(item.minAppVersion, "1.2.0")

        let unknownTypeDTO = FilterCatalogItemDTO(
            id: itemId,
            slug: "custom",
            name: "Custom",
            type: "UNKNOWN_TYPE",
            thumbnailUrl: nil,
            assetUrl: "https://cdn.splick.com/filters/unknown.cube",
            version: 1,
            minAppVersion: nil
        )
        let unknownItem = try FilterCatalogMapper.map(unknownTypeDTO)
        XCTAssertEqual(unknownItem.type, .lut)
        XCTAssertNil(unknownItem.thumbnailURL)
    }

    func testFilterCatalogMapperInvalidAssetURL() {
        let invalidDTO = FilterCatalogItemDTO(
            id: UUID(),
            slug: "invalid",
            name: "Invalid",
            type: "LUT",
            thumbnailUrl: nil,
            assetUrl: "",
            version: 1,
            minAppVersion: nil
        )
        XCTAssertThrowsError(try FilterCatalogMapper.map(invalidDTO)) { error in
            XCTAssertEqual(error as? FilterCatalogError, .invalidAssetURL)
        }
    }
}
