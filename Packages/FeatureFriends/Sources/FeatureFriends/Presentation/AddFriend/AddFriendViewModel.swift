import Foundation
import SplickDomain

@MainActor
public final class AddFriendViewModel: ObservableObject {
    @Published var username = ""
    @Published var isLoading = false
    @Published var successMessage: String?
    @Published var errorMessage: String?

    private let addFriendUseCase: AddFriendUseCaseProtocol
    private let onSuccess: () -> Void

    public init(
        addFriendUseCase: AddFriendUseCaseProtocol,
        onSuccess: @escaping () -> Void
    ) {
        self.addFriendUseCase = addFriendUseCase
        self.onSuccess = onSuccess
    }

    func addByUsername() async {
        let normalized = username.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
        guard !normalized.isEmpty else {
            errorMessage = "Enter a username."
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            let user = try await addFriendUseCase.execute(username: normalized)
            successMessage = "Added \(user.displayName)."
            username = ""
            onSuccess()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addFromQR(_ payload: String) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            let user = try await addFriendUseCase.executeFromQRCode(payload)
            successMessage = "Added \(user.displayName)."
            onSuccess()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
