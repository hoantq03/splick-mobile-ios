import Foundation

public protocol NearbyDiscoveryUseCaseProtocol: Sendable {
    func preference() async throws -> Bool
    func setPreference(_ enabled: Bool) async throws -> Bool
    func nearbyUsers(lat: Double, lon: Double) async throws -> [UserSearchResult]
    func leaveSession() async throws
}

public struct NearbyDiscoveryUseCase: NearbyDiscoveryUseCaseProtocol {
    private let repository: FriendsManagementRepositoryProtocol

    public init(repository: FriendsManagementRepositoryProtocol) {
        self.repository = repository
    }

    public func preference() async throws -> Bool {
        try await repository.discoveryPreference()
    }

    public func setPreference(_ enabled: Bool) async throws -> Bool {
        try await repository.updateDiscoveryPreference(nearbyEnabled: enabled)
    }

    public func nearbyUsers(lat: Double, lon: Double) async throws -> [UserSearchResult] {
        try await repository.findNearbyUsers(lat: lat, lon: lon)
    }

    public func leaveSession() async throws {
        try await repository.leaveNearbySession()
    }
}
