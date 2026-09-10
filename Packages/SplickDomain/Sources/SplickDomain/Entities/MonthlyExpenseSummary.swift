import Foundation

public struct MonthlyExpenseSummary: Equatable, Sendable {
  public let currency: String
  public let currentMonth: MonthData
  public let months: [MonthData]

  public init(currency: String, currentMonth: MonthData, months: [MonthData]) {
    self.currency = currency
    self.currentMonth = currentMonth
    self.months = months
  }
}

public struct MonthData: Equatable, Identifiable, Sendable {
  public var id: String { "\(year)-\(month)" }
  public let year: Int
  public let month: Int
  public let totalSettledReceived: Decimal
  public let totalSettledPaid: Decimal

  public init(
    year: Int,
    month: Int,
    totalSettledReceived: Decimal,
    totalSettledPaid: Decimal
  ) {
    self.year = year
    self.month = month
    self.totalSettledReceived = totalSettledReceived
    self.totalSettledPaid = totalSettledPaid
  }
}
