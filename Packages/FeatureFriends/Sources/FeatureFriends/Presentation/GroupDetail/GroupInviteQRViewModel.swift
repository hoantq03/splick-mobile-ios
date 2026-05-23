import Foundation

@MainActor
final class GroupInviteQRViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded(GroupServerQR)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published var alertMessage: String?

    private let groupId: UUID
    private let generateGroupQrUseCase: GenerateGroupQrUseCaseProtocol
    private let revokeGroupQrUseCase: RevokeGroupQrUseCaseProtocol

    init(
        groupId: UUID,
        generateGroupQrUseCase: GenerateGroupQrUseCaseProtocol,
        revokeGroupQrUseCase: RevokeGroupQrUseCaseProtocol
    ) {
        self.groupId = groupId
        self.generateGroupQrUseCase = generateGroupQrUseCase
        self.revokeGroupQrUseCase = revokeGroupQrUseCase
    }

    var serverQR: GroupServerQR? {
        if case .loaded(let qr) = state { return qr }
        return nil
    }

    var qrPayload: String? {
        serverQR?.payload
    }

    func load() async {
        state = .loading
        do {
            try await regenerate()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func regenerate() async throws {
        state = .loading
        let qr = try await generateGroupQrUseCase.execute(groupId: groupId, ttlSeconds: 86_400)
        state = .loaded(qr)
    }

    func refresh() async {
        if let existing = serverQR {
            do {
                try await revokeGroupQrUseCase.execute(groupId: groupId, qrId: existing.id)
            } catch {
                alertMessage = error.localizedDescription
                return
            }
        }
        do {
            try await regenerate()
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
