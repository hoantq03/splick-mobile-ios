import Foundation
import Common
import SplickDomain

@MainActor
public final class PeopleYouMayKnowViewModel: ObservableObject {
    @Published var suggestions: [PeopleYouMayKnowSuggestion] = []
    @Published private(set) var suggestionCount = 0
    @Published var state: LoadingState<[PeopleYouMayKnowSuggestion]> = .idle
    @Published var processingUserIds: Set<UUID> = []
    @Published var alertMessage: String?

    private let fetchPeopleYouMayKnowUseCase: FetchPeopleYouMayKnowUseCaseProtocol
    private let addFriendUseCase: AddFriendUseCaseProtocol
    private let onRelationshipChanged: (UUID, FriendRelationStatus) -> Void
    private var loadTask: Task<Void, Never>?

    public init(
        fetchPeopleYouMayKnowUseCase: FetchPeopleYouMayKnowUseCaseProtocol,
        addFriendUseCase: AddFriendUseCaseProtocol,
        onRelationshipChanged: @escaping (UUID, FriendRelationStatus) -> Void
    ) {
        self.fetchPeopleYouMayKnowUseCase = fetchPeopleYouMayKnowUseCase
        self.addFriendUseCase = addFriendUseCase
        self.onRelationshipChanged = onRelationshipChanged
    }

    func load(
        currentUserId: UUID? = nil,
        snapshot: PeopleYouMayKnowDirectorySnapshot? = nil
    ) async {
        if let existing = loadTask {
            await existing.value
            return
        }

        let task = Task { @MainActor in
            await performLoad(currentUserId: currentUserId, snapshot: snapshot)
        }
        loadTask = task
        await task.value
        loadTask = nil
    }

    private func performLoad(
        currentUserId: UUID?,
        snapshot: PeopleYouMayKnowDirectorySnapshot?
    ) async {
        if suggestions.isEmpty {
            state = .loading
        }
        do {
            let items = try await fetchPeopleYouMayKnowUseCase.execute(
                currentUserId: currentUserId,
                snapshot: snapshot
            )
            suggestions = items
            suggestionCount = items.count
            state = .loaded(items)
        } catch {
            if suggestions.isEmpty {
                suggestions = []
                suggestionCount = 0
                state = .failed(error.localizedDescription)
            } else {
                state = .loaded(suggestions)
            }
        }
    }

    func sendFriendRequest(to suggestion: PeopleYouMayKnowSuggestion) async {
        guard suggestion.friendStatus == .none else { return }
        let userId = suggestion.user.id
        guard !processingUserIds.contains(userId) else { return }
        processingUserIds.insert(userId)

        removeSuggestionLocally(userId)
        onRelationshipChanged(userId, .requestSent)

        defer { processingUserIds.remove(userId) }

        do {
            _ = try await addFriendUseCase.execute(username: suggestion.user.username, message: nil)
        } catch {
            restoreSuggestionLocally(suggestion)
            onRelationshipChanged(userId, .none)
            alertMessage = error.localizedDescription
        }
    }

    private func removeSuggestionLocally(_ userId: UUID) {
        suggestions.removeAll { $0.user.id == userId }
        suggestionCount = suggestions.count
        state = suggestions.isEmpty ? .loaded([]) : .loaded(suggestions)
    }

    private func restoreSuggestionLocally(_ suggestion: PeopleYouMayKnowSuggestion) {
        guard !suggestions.contains(where: { $0.user.id == suggestion.user.id }) else { return }
        suggestions.append(suggestion)
        suggestions.sort {
            $0.user.displayName.localizedCaseInsensitiveCompare($1.user.displayName) == .orderedAscending
        }
        suggestionCount = suggestions.count
        state = .loaded(suggestions)
    }
}
