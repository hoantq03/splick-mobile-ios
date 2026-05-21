import Foundation

@MainActor
final class GroupInviteQRViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded(code: String)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published var alertMessage: String?

    private let groupId: UUID
    private let fetchInviteCodeUseCase: FetchGroupInviteCodeUseCaseProtocol
    private let generateInviteCodeUseCase: GenerateGroupInviteCodeUseCaseProtocol

    init(
        groupId: UUID,
        fetchInviteCodeUseCase: FetchGroupInviteCodeUseCaseProtocol,
        generateInviteCodeUseCase: GenerateGroupInviteCodeUseCaseProtocol
    ) {
        self.groupId = groupId
        self.fetchInviteCodeUseCase = fetchInviteCodeUseCase
        self.generateInviteCodeUseCase = generateInviteCodeUseCase
    }

    var inviteCode: String? {
        if case .loaded(let code) = state { return code }
        return nil
    }

    var qrPayload: String? {
        guard let code = inviteCode else { return nil }
        return SplickQRParser.groupPayload(inviteCode: code)
    }

    func load() async {
        state = .loading
        do {
            if let existing = try await fetchInviteCodeUseCase.execute(groupId: groupId) {
                state = .loaded(code: existing.code)
            } else {
                try await regenerate()
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func regenerate() async throws {
        state = .loading
        let invite = try await generateInviteCodeUseCase.execute(groupId: groupId)
        state = .loaded(code: invite.code)
    }

    func refresh() async {
        do {
            try await regenerate()
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
