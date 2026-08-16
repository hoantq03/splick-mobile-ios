import Foundation
import Networking

enum ExpenseEndpoint: APIEndpoint {
  case list(groupId: UUID?, page: Int, limit: Int, cursor: String?)
  case detail(id: UUID)
  case create(CreateExpenseRequestDTO)
  case settle(expenseId: UUID, SettleExpenseRequestDTO)
  case debtSummary(groupId: UUID?)
  case monthlySummary(months: Int)
  case withCounterparty(
    id: UUID, page: Int, limit: Int, status: CounterpartyExpenseStatus, cursor: String?
  )
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
    case .monthlySummary: return "/v1/expenses/monthly-summary"
    case .withCounterparty(let id, _, _, _, _): return "/v1/expenses/with-user/\(id)"
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
    case .list, .detail, .debtSummary, .monthlySummary, .withCounterparty, .netting: return .get
    case .create, .settle, .submitBulkSettlement, .approveBulkSettlement,
      .rejectBulkSettlement:
      return .post
    }
  }

  var queryItems: [URLQueryItem]? {
    switch self {
    case .list(let groupId, let page, let limit, let cursor):
      var items = [
        URLQueryItem(name: "limit", value: "\(limit)")
      ]
      if let cursor, !cursor.isEmpty {
        items.append(URLQueryItem(name: "cursor", value: cursor))
      } else {
        items.append(URLQueryItem(name: "page", value: "\(page)"))
      }
      if let groupId {
        items.append(URLQueryItem(name: "groupId", value: groupId.uuidString))
      }
      return items

    case .debtSummary(let groupId):
      guard let groupId else { return nil }
      return [URLQueryItem(name: "groupId", value: groupId.uuidString)]

    case .monthlySummary(let months):
      return [URLQueryItem(name: "months", value: "\(months)")]

    case .withCounterparty(_, let page, let limit, let status, let cursor):
      var items = [
        URLQueryItem(name: "limit", value: "\(limit)"),
        URLQueryItem(name: "status", value: status.rawValue),
      ]
      if let cursor, !cursor.isEmpty {
        items.append(URLQueryItem(name: "cursor", value: cursor))
      } else {
        items.append(URLQueryItem(name: "page", value: "\(page)"))
      }
      return items

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
