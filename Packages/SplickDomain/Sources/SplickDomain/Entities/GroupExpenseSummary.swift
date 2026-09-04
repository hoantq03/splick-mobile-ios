import Foundation

public struct GroupExpenseSummary: Equatable, Sendable {
  public let groups: [GroupExpenseItem]

  public init(groups: [GroupExpenseItem]) {
    self.groups = groups
  }
}

public struct GroupExpenseItem: Identifiable, Equatable, Sendable {
  public var id: UUID { groupId }
  public let groupId: UUID
  public let groupName: String
  public let groupAvatarURL: URL?
  public let totalGroupSpending: Decimal
  public let userPaidTotal: Decimal
  public let userBalance: Decimal
  public let currency: String
  public let memberAvatars: [UserSummary]

  public init(
    groupId: UUID,
    groupName: String,
    groupAvatarURL: URL?,
    totalGroupSpending: Decimal,
    userPaidTotal: Decimal,
    userBalance: Decimal,
    currency: String,
    memberAvatars: [UserSummary]
  ) {
    self.groupId = groupId
    self.groupName = groupName
    self.groupAvatarURL = groupAvatarURL
    self.totalGroupSpending = totalGroupSpending
    self.userPaidTotal = userPaidTotal
    self.userBalance = userBalance
    self.currency = currency
    self.memberAvatars = memberAvatars
  }
}
