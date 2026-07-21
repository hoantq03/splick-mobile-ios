import Foundation
import Networking

enum ExpenseEndpoint: APIEndpoint {
  case list(groupId: UUID?, page: Int, limit: Int)
  case detail(id: UUID)
  case create(CreateExpenseRequestDTO)
  case settle(expenseId: UUID, SettleExpenseRequestDTO)
  case debtSummary(groupId: UUID?)
  case withCounterparty(id: UUID, page: Int, limit: Int, status: CounterpartyExpenseStatus)
  case netting(counterpartyId: UUID)
  case submitBulkSettlement(counterpartyId: UUID, SubmitBulkSettlementRequestDTO)
  case approveBulkSettlement(id: UUID)
  case rejectBulkSettlement(id: UUID, RejectBulkSettlementRequestDTO)

  var path: String {
    switch self {
    case .list: return "/v1/expenses"
    case .detail(let id): return "/v1/expenses/\(id)"
    case .create: return "/v1/expenses"
    case .settle(let expenseId, _): return "/v1/expenses/\(expenseId)/settle"
    case .debtSummary: return "/v1/expenses/debts"
    case .withCounterparty(let id, _, _, _): return "/v1/expenses/with-user/\(id)"
    case .netting(let counterpartyId): return "/v1/expenses/netting/\(counterpartyId)"
    case .submitBulkSettlement(let counterpartyId, _):
      return "/v1/expenses/netting/\(counterpartyId)/settle"
    case .approveBulkSettlement(let id):
      return "/v1/expenses/netting/settlements/\(id)/approve"
    case .rejectBulkSettlement(let id, _):
      return "/v1/expenses/netting/settlements/\(id)/reject"
    }
  }

  var method: HTTPMethod {
    switch self {
    case .list, .detail, .debtSummary, .withCounterparty, .netting: return .get
    case .create, .settle, .submitBulkSettlement, .approveBulkSettlement,
      .rejectBulkSettlement:
      return .post
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

    case .withCounterparty(_, let page, let limit, let status):
      return [
        URLQueryItem(name: "page", value: "\(page)"),
        URLQueryItem(name: "limit", value: "\(limit)"),
        URLQueryItem(name: "status", value: status.rawValue),
      ]

    default: return nil
    }
  }

  var body: Encodable? {
    switch self {
    case .create(let dto): return dto
    case .settle(_, let dto): return dto
    case .submitBulkSettlement(_, let dto): return dto
    case .rejectBulkSettlement(_, let dto): return dto
    default: return nil
    }
  }
}
