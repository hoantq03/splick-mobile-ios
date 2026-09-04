import Foundation
import Common
import Localization

@MainActor
final class GroupInviteQRViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded(GroupServerQR)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var isRefreshing = false
    @Published var alertMessage: String?

    private let groupId: UUID
    private let generateGroupQrUseCase: GenerateGroupQrUseCaseProtocol
    private let revokeGroupQrUseCase: RevokeGroupQrUseCaseProtocol
    private let languageService: LanguageService

    init(
        groupId: UUID,
        generateGroupQrUseCase: GenerateGroupQrUseCaseProtocol,
        revokeGroupQrUseCase: RevokeGroupQrUseCaseProtocol,
        languageService: LanguageService
    ) {
        self.groupId = groupId
        self.generateGroupQrUseCase = generateGroupQrUseCase
        self.revokeGroupQrUseCase = revokeGroupQrUseCase
        self.languageService = languageService
    }

    var serverQR: GroupServerQR? {
        if case .loaded(let qr) = state { return qr }
        return nil
    }

    var qrPayload: String? {
        serverQR?.payload
    }

    var shareURL: URL? {
        guard let payload = qrPayload else { return nil }
        if let action = SplickQRParser.parse(payload),
           case .joinGroup(let inviteCode) = action {
            return AppConstants.Links.groupInviteURL(inviteCode: inviteCode)
        }
        return AppConstants.Links.groupQrJoinURL(payload: payload)
    }

    func load() async {
        state = .loading
        do {
            try await regenerate()
        } catch {
            state = .failed(languageService.localizedMessage(for: error))
        }
    }

    func regenerate() async throws {
        state = .loading
        let qr = try await generateGroupQrUseCase.execute(groupId: groupId, ttlSeconds: 86_400)
        state = .loaded(qr)
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        if let existing = serverQR {
            do {
                try await revokeGroupQrUseCase.execute(groupId: groupId, qrId: existing.id)
            } catch {
                alertMessage = languageService.localizedMessage(for: error)
                return
            }
        }
        do {
            let qr = try await generateGroupQrUseCase.execute(groupId: groupId, ttlSeconds: 86_400)
            state = .loaded(qr)
        } catch {
            alertMessage = languageService.localizedMessage(for: error)
        }
    }
}
