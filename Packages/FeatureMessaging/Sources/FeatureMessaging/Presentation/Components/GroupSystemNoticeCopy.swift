import Foundation
import Localization
import SplickDomain

enum GroupSystemNoticeCopy {
    @MainActor
    static func text(
        message: ChatMessage,
        currentUserId: UUID?,
        actorName: String?,
        languageService: LanguageService
    ) -> String {
        guard message.type == .groupRenamed else { return message.body }
        let newName = message.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if message.senderId == currentUserId {
            return languageService.format(.messagingGroupRenamedNoticeYou, newName)
        }
        let actor = actorName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if actor.isEmpty {
            return languageService.format(.messagingGroupRenamedNoticeUnknown, newName)
        }
        return languageService.format(.messagingGroupRenamedNotice, actor, newName)
    }
}
