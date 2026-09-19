import Foundation

public struct SpendingAnalytics: Equatable, Sendable {
  public let trend: [SpendingTrendPoint]
  public let categories: [SpendingCategoryBreakdown]
  public let currency: String

  public init(
    trend: [SpendingTrendPoint],
    categories: [SpendingCategoryBreakdown],
    currency: String
  ) {
    self.trend = trend
    self.categories = categories
    self.currency = currency
  }
}

public struct SpendingTrendPoint: Identifiable, Equatable, Sendable {
  public var id: Date { bucketStart }
  public let bucketStart: Date
  public let amount: Decimal

  public init(bucketStart: Date, amount: Decimal) {
    self.bucketStart = bucketStart
    self.amount = amount
  }
}

public struct SpendingCategoryBreakdown: Identifiable, Equatable, Sendable {
  public var id: String { category.rawValue }
  public let category: ExpenseCategory
  public let amount: Decimal
  public let percentage: Decimal

  public init(category: ExpenseCategory, amount: Decimal, percentage: Decimal) {
    self.category = category
    self.amount = amount
    self.percentage = percentage
  }
}

public enum SpendingAnalyticsPeriod: String, Sendable {
  case week = "WEEK"
  case month = "MONTH"
}
