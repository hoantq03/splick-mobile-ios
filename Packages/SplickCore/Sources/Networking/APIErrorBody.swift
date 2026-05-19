import Foundation

public struct APIErrorBody: Decodable, Sendable {
    public let status: Int
    public let error: String
    public let message: String
}
