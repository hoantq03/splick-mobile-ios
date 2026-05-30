import Foundation

public struct ConnectedAccounts: Equatable, Sendable {
    public let google: ConnectedProvider
    public let emailPassword: ConnectedProvider
    public let phone: ConnectedProvider

    public init(google: ConnectedProvider, emailPassword: ConnectedProvider, phone: ConnectedProvider) {
        self.google = google
        self.emailPassword = emailPassword
        self.phone = phone
    }
}

public struct ConnectedProvider: Equatable, Sendable {
    public let isLinked: Bool
    public let detail: String?

    public init(isLinked: Bool, detail: String?) {
        self.isLinked = isLinked
        self.detail = detail
    }
}
