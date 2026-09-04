import Foundation

public struct APIErrorBody: Decodable, Sendable {
    public let status: Int
    public let error: String
    public let message: String
    public let traceId: String?

    public let deactivatedAt: Date?
    public let scheduledDeletionAt: Date?
    public let reactivationToken: String?

    public init(
        status: Int,
        error: String,
        message: String,
        traceId: String? = nil,
        deactivatedAt: Date? = nil,
        scheduledDeletionAt: Date? = nil,
        reactivationToken: String? = nil
    ) {
        self.status = status
        self.error = error
        self.message = message
        self.traceId = traceId
        self.deactivatedAt = deactivatedAt
        self.scheduledDeletionAt = scheduledDeletionAt
        self.reactivationToken = reactivationToken
    }
}
