import Foundation
import SplickDomain

@MainActor
public final class JoinGroupViewModel: ObservableObject {
    @Published var inviteCode = ""
    @Published var isLoading = false
    @Published var successMessage: String?
    @Published var errorMessage: String?

    private let joinGroupUseCase: JoinGroupUseCaseProtocol
    private let onSuccess: () -> Void

    public init(
        joinGroupUseCase: JoinGroupUseCaseProtocol,
        onSuccess: @escaping () -> Void
    ) {
        self.joinGroupUseCase = joinGroupUseCase
        self.onSuccess = onSuccess
    }

    func joinByCode() async {
        let normalized = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else {
            errorMessage = "Enter a group invite code."
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            let group = try await joinGroupUseCase.execute(inviteCode: normalized)
            successMessage = "Joined \(group.name)."
            inviteCode = ""
            onSuccess()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func joinFromQR(_ payload: String) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            let group = try await joinGroupUseCase.executeFromQRCode(payload)
            successMessage = "Joined \(group.name)."
            onSuccess()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
