import Localization

extension ConversationMutePreset {
    var titleKey: L10nKey {
        switch self {
        case .fifteenMinutes: return .messagingChatMute15Minutes
        case .oneHour: return .messagingChatMute1Hour
        case .eightHours: return .messagingChatMute8Hours
        case .twentyFourHours: return .messagingChatMute24Hours
        case .untilSevenAM: return .messagingChatMuteUntil7Am
        case .forever: return .messagingChatMuteForever
        }
    }
}
