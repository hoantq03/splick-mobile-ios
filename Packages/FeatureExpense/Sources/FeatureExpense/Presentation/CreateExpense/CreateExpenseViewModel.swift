import Foundation
import SwiftUI
import Common
import Localization
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
    private let languageService: LanguageService

    public init(
        createExpenseUseCase: CreateExpenseUseCaseProtocol,
        groupId: UUID? = nil,
        languageService: LanguageService
    ) {
        self.createExpenseUseCase = createExpenseUseCase
        self.groupId = groupId
        self.languageService = languageService
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
            state = .failed(languageService.localizedMessage(for: error))
        } catch {
            state = .failed(languageService.text(.expenseCreateFailed))
            Log.error(error, category: .expense)
        }
    }

    private func validate() -> Bool {
        var isValid = true
        descriptionError = nil
        amountError = nil

        if description.trimmed.isEmpty {
            descriptionError = languageService.text(.expenseDescriptionRequired)
            isValid = false
        }

        guard let amountValue = Decimal(string: amount), amountValue > 0 else {
            amountError = languageService.text(.expenseAmountInvalid)
            isValid = false
            return isValid
        }

        if selectedParticipants.isEmpty {
            state = .failed(languageService.text(.expenseNeedParticipant))
            isValid = false
        }

        return isValid
    }
}
