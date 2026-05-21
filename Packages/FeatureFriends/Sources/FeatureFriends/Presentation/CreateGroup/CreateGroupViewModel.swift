import Foundation
import SplickDomain

@MainActor
public final class CreateGroupViewModel: ObservableObject {
    @Published var name = ""
    @Published var groupDescription = ""
    @Published var isLoading = false
    @Published var successMessage: String?
    @Published var errorMessage: String?

    private let createGroupUseCase: CreateGroupUseCaseProtocol
    private let onSuccess: (Group) -> Void

    public init(
        createGroupUseCase: CreateGroupUseCaseProtocol,
        onSuccess: @escaping (Group) -> Void
    ) {
        self.createGroupUseCase = createGroupUseCase
        self.onSuccess = onSuccess
    }

    func create() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Nhập tên nhóm."
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        let description = groupDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let group = try await createGroupUseCase.execute(
                name: trimmedName,
                description: description.isEmpty ? nil : description
            )
            successMessage = "Đã tạo nhóm \(group.name)."
            name = ""
            groupDescription = ""
            onSuccess(group)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
