import Foundation
import Localization
import SplickDomain

@MainActor
public final class NearbyRadarSessionViewModel: ObservableObject {
    @Published public var nearbyPermissionNeeded = false
    @Published public var nearbyUsers: [UserSearchResult] = []
    @Published public var nearbyLoading = false
    @Published public var alertMessage: String?

    private let nearbyDiscoveryUseCase: NearbyDiscoveryUseCaseProtocol
    private let addFriendUseCase: AddFriendUseCaseProtocol
    private let acceptFriendRequestUseCase: AcceptFriendRequestUseCaseProtocol
    private let cancelFriendRequestUseCase: CancelFriendRequestUseCaseProtocol
    private let fetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCaseProtocol
    private let fetchOutgoingFriendRequestsUseCase: FetchOutgoingFriendRequestsUseCaseProtocol
    private let languageService: LanguageService
    private let locationProvider = NearbyLocationProvider()
    private var nearbyTask: Task<Void, Never>?
    private var inFlightRelationActionUserIds: Set<UUID> = []
    private var relationOverrides: [UUID: FriendRelationStatus] = [:]

    public init(
        nearbyDiscoveryUseCase: NearbyDiscoveryUseCaseProtocol,
        addFriendUseCase: AddFriendUseCaseProtocol,
        acceptFriendRequestUseCase: AcceptFriendRequestUseCaseProtocol,
        cancelFriendRequestUseCase: CancelFriendRequestUseCaseProtocol,
        fetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCaseProtocol,
        fetchOutgoingFriendRequestsUseCase: FetchOutgoingFriendRequestsUseCaseProtocol,
        languageService: LanguageService
    ) {
        self.nearbyDiscoveryUseCase = nearbyDiscoveryUseCase
        self.addFriendUseCase = addFriendUseCase
        self.acceptFriendRequestUseCase = acceptFriendRequestUseCase
        self.cancelFriendRequestUseCase = cancelFriendRequestUseCase
        self.fetchIncomingFriendRequestsUseCase = fetchIncomingFriendRequestsUseCase
        self.fetchOutgoingFriendRequestsUseCase = fetchOutgoingFriendRequestsUseCase
        self.languageService = languageService
    }

    public func startRadarSession() {
        nearbyTask?.cancel()
        locationProvider.onAuthorizationChange = { [weak self] in
            Task { @MainActor in
                await self?.refreshNearby()
            }
        }
        nearbyTask = Task { @MainActor in
            _ = try? await nearbyDiscoveryUseCase.setPreference(true)
            nearbyPermissionNeeded = !locationProvider.hasAuthorization
            if nearbyPermissionNeeded {
                locationProvider.requestAuthorization()
            }
            while !Task.isCancelled {
                await refreshNearby()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    public func stopRadarSession() {
        nearbyTask?.cancel()
        nearbyTask = nil
        locationProvider.onAuthorizationChange = nil
        relationOverrides.removeAll()
        Task {
            try? await nearbyDiscoveryUseCase.leaveSession()
            nearbyUsers = []
            nearbyLoading = false
            nearbyPermissionNeeded = false
        }
    }

    public func requestNearbyLocationAccess() {
        locationProvider.requestAuthorization()
        Task { await refreshNearby() }
    }

    public func actionForResult(_ result: UserSearchResult) -> (() -> Void)? {
        switch result.friendStatus {
        case .none:
            return { [weak self] in self?.sendFriendRequest(to: result) }
        case .requestReceived:
            return { [weak self] in self?.acceptFriendRequest(from: result) }
        case .requestSent:
            return { [weak self] in self?.cancelFriendRequest(from: result) }
        case .friends, .blocked:
            return nil
        }
    }

    private func refreshNearby() async {
        if !locationProvider.hasAuthorization {
            nearbyPermissionNeeded = true
            nearbyLoading = false
            return
        }
        nearbyPermissionNeeded = false
        if nearbyUsers.isEmpty {
            nearbyLoading = true
        }
        guard let coordinate = await locationProvider.currentCoordinate() else {
            nearbyLoading = false
            return
        }
        do {
            nearbyUsers = applyRelationOverrides(
                try await nearbyDiscoveryUseCase.nearbyUsers(
                    lat: coordinate.latitude,
                    lon: coordinate.longitude
                )
            )
            nearbyLoading = false
        } catch {
            nearbyLoading = false
        }
    }

    private func sendFriendRequest(to result: UserSearchResult) {
        guard result.friendStatus == .none else { return }
        let userId = result.user.id
        guard !inFlightRelationActionUserIds.contains(userId) else { return }
        inFlightRelationActionUserIds.insert(userId)
        updateRelation(userId: userId, status: .requestSent)
        Task {
            defer { inFlightRelationActionUserIds.remove(userId) }
            do {
                _ = try await addFriendUseCase.execute(username: result.user.username, message: nil)
            } catch {
                updateRelation(userId: userId, status: .none)
                alertMessage = languageService.localizedMessage(for: error)
            }
        }
    }

    private func acceptFriendRequest(from result: UserSearchResult) {
        guard result.friendStatus == .requestReceived else { return }
        let userId = result.user.id
        guard !inFlightRelationActionUserIds.contains(userId) else { return }
        inFlightRelationActionUserIds.insert(userId)
        updateRelation(userId: userId, status: .friends)
        Task {
            defer { inFlightRelationActionUserIds.remove(userId) }
            do {
                let incoming = try await fetchIncomingFriendRequestsUseCase.executeAll()
                guard let request = incoming.first(where: { $0.requester.id == userId }) else {
                    updateRelation(userId: userId, status: .requestReceived)
                    alertMessage = languageService.text(.friendsRequestNotFoundIncoming)
                    return
                }
                try await acceptFriendRequestUseCase.execute(requestId: request.id)
            } catch {
                updateRelation(userId: userId, status: .requestReceived)
                alertMessage = languageService.localizedMessage(for: error)
            }
        }
    }

    private func cancelFriendRequest(from result: UserSearchResult) {
        guard result.friendStatus == .requestSent else { return }
        let userId = result.user.id
        guard !inFlightRelationActionUserIds.contains(userId) else { return }
        inFlightRelationActionUserIds.insert(userId)
        updateRelation(userId: userId, status: .none)
        Task {
            defer { inFlightRelationActionUserIds.remove(userId) }
            do {
                let outgoing = try await fetchOutgoingFriendRequestsUseCase.executeAll()
                guard let request = outgoing.first(where: { $0.addressee.id == userId }) else {
                    updateRelation(userId: userId, status: .requestSent)
                    return
                }
                try await cancelFriendRequestUseCase.execute(requestId: request.id)
            } catch {
                updateRelation(userId: userId, status: .requestSent)
                alertMessage = languageService.localizedMessage(for: error)
            }
        }
    }

    private func updateRelation(userId: UUID, status: FriendRelationStatus) {
        relationOverrides[userId] = status
        nearbyUsers = nearbyUsers.map { item in
            guard item.user.id == userId else { return item }
            return UserSearchResult(user: item.user, friendStatus: status, distanceMeters: item.distanceMeters)
        }
    }

    private func applyRelationOverrides(_ users: [UserSearchResult]) -> [UserSearchResult] {
        users.map { item in
            guard let override = relationOverrides[item.user.id] else { return item }
            if item.friendStatus == override {
                relationOverrides.removeValue(forKey: item.user.id)
                return item
            }
            return UserSearchResult(
                user: item.user,
                friendStatus: override,
                distanceMeters: item.distanceMeters
            )
        }
    }
}
