import Foundation

public enum SplickBot {
    public static let userId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    public static let username = "splick_bot"
    public static let displayName = "Splick Bot thơ nụ"

    public static let remindersSentCount = 99_999
    public static let recoveryRatePercent = 99
    public static let yearsExperience = 10

    public static func isBot(_ userId: UUID?) -> Bool {
        guard let userId else { return false }
        return userId == self.userId
    }
}
