import Foundation
import SwiftUI
import Common
import SplickDomain

@MainActor
public final class CreateExpenseViewModel: ObservableObject {
    @Published var description = ""
    @Published var amount = ""
    @Published var selectedCategory: ExpenseCategory = .general
    @Published var splitType: SplitType = .equal
    @Published var selectedParticipants: Set<UUID> = []
    @Published var state: LoadingState<Expense> = .idle
    @Published var descriptionError: String?
    @Published var amountError: String?

    private let createExpenseUseCase: CreateExpenseUseCaseProtocol
    private let groupId: UUID?

    public init(createExpenseUseCase: CreateExpenseUseCaseProtocol, groupId: UUID? = nil) {
        self.createExpenseUseCase = createExpenseUseCase
        self.groupId = groupId
    }

    func createExpense() async {
        guard validate() else { return }

        state = .loading
        do {
            let request = CreateExpenseRequest(
                description: description.trimmed,
                totalAmount: Decimal(string: amount) ?? 0,
                groupId: groupId,
                category: selectedCategory,
                splitType: splitType,
                participants: Array(selectedParticipants)
            )
            let expense = try await createExpenseUseCase.execute(request)
            state = .loaded(expense)
            Log.info("Expense created: \(expense.id)", category: .expense)
        } catch let error as AppError {
            state = .failed(error.userMessage)
        } catch {
            state = .failed("Failed to create expense")
            Log.error(error, category: .expense)
        }
    }

    private func validate() -> Bool {
        var isValid = true
        descriptionError = nil
        amountError = nil

        if description.trimmed.isEmpty {
            descriptionError = "Description is required"
            isValid = false
        }

        guard let amountValue = Decimal(string: amount), amountValue > 0 else {
            amountError = "Enter a valid amount"
            isValid = false
            return isValid
        }

        if selectedParticipants.isEmpty {
            state = .failed("Select at least one participant")
            isValid = false
        }

        return isValid
    }
}
