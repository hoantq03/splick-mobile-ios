import Foundation

public enum MessageDeliveryStatus: String, Equatable, Sendable, Codable {
    case sending
    case sent
    case delivered
    case read
    case failed
}
