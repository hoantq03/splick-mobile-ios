import Foundation

public enum ConversationMutePreset: String, CaseIterable, Sendable, Hashable {
    case fifteenMinutes
    case oneHour
    case eightHours
    case twentyFourHours
    case untilSevenAM
    case forever
}

public enum ConversationMuteRemainingUnit: Sendable {
    case minutes
    case hours
    case days
}

public struct ConversationMuteRemaining: Equatable, Sendable {
    public let amount: Int
    public let unit: ConversationMuteRemainingUnit
}

public enum ConversationMuteSchedule {
    public static func mutedUntil(
        preset: ConversationMutePreset,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        switch preset {
        case .fifteenMinutes:
            return now.addingTimeInterval(15 * 60)
        case .oneHour:
            return now.addingTimeInterval(60 * 60)
        case .eightHours:
            return now.addingTimeInterval(8 * 60 * 60)
        case .twentyFourHours:
            return now.addingTimeInterval(24 * 60 * 60)
        case .untilSevenAM:
            return nextSevenAM(now: now, calendar: calendar)
        case .forever:
            return nil
        }
    }

    /// Remaining mute time for inbox badges. Nil if forever or expired.
    public static func remaining(mutedUntil: Date?, now: Date = Date()) -> ConversationMuteRemaining? {
        guard let mutedUntil else { return nil }
        let seconds = mutedUntil.timeIntervalSince(now)
        if seconds <= 0 { return nil }
        let minutes = Int((seconds + 59) / 60)
        if minutes < 60 {
            return ConversationMuteRemaining(amount: minutes, unit: .minutes)
        }
        if minutes < 24 * 60 {
            return ConversationMuteRemaining(amount: minutes / 60, unit: .hours)
        }
        return ConversationMuteRemaining(amount: minutes / (24 * 60), unit: .days)
    }

    private static func nextSevenAM(now: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 7
        components.minute = 0
        components.second = 0
        let todaySeven = calendar.date(from: components) ?? now
        if todaySeven > now {
            return todaySeven
        }
        return calendar.date(byAdding: .day, value: 1, to: todaySeven) ?? todaySeven
    }
}
