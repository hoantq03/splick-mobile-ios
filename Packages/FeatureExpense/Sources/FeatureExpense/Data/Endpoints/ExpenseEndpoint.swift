import Foundation
import Networking

enum ExpenseEndpoint: APIEndpoint {
    case list(groupId: UUID?, page: Int, limit: Int)
    case detail(id: UUID)
    case create(CreateExpenseRequestDTO)
    case settle(expenseId: UUID, SettleExpenseRequestDTO)
    case debtSummary(groupId: UUID?)

    var path: String {
        switch self {
        case .list: return "/v1/expenses"
        case .detail(let id): return "/v1/expenses/\(id)"
        case .create: return "/v1/expenses"
        case .settle(let expenseId, _): return "/v1/expenses/\(expenseId)/settle"
        case .debtSummary: return "/v1/expenses/debts"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .detail, .debtSummary: return .get
        case .create: return .post
        case .settle: return .post
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .list(let groupId, let page, let limit):
            var items = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)"),
            ]
            if let groupId {
                items.append(URLQueryItem(name: "groupId", value: groupId.uuidString))
            }
            return items

        case .debtSummary(let groupId):
            guard let groupId else { return nil }
            return [URLQueryItem(name: "groupId", value: groupId.uuidString)]

        default: return nil
        }
    }

    var body: Encodable? {
        switch self {
        case .create(let dto): return dto
        case .settle(_, let dto): return dto
        default: return nil
        }
    }
}
