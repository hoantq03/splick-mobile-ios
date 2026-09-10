import Foundation

public struct PostPlace: Sendable, Equatable, Hashable {
    public let placeId: String?
    public let displayName: String
    public let lat: Double?
    public let lon: Double?

    public init(
        placeId: String? = nil,
        displayName: String,
        lat: Double? = nil,
        lon: Double? = nil
    ) {
        self.placeId = placeId
        self.displayName = displayName
        self.lat = lat
        self.lon = lon
    }

    public var hasCoordinates: Bool { lat != nil || placeId != nil }
}
