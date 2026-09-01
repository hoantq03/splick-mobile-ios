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
        let actor = actorName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedType: ChatMessageType? = GroupSystemNoticePayload.isMemberLeft(message.body)
            ? .groupMemberLeft
            : message.type
        switch resolvedType {
        case .groupRenamed:
            let newName = message.body.trimmingCharacters(in: .whitespacesAndNewlines)
            if message.senderId == currentUserId {
                return languageService.format(.messagingGroupRenamedNoticeYou, newName)
            }
            if actor.isEmpty {
                return languageService.format(.messagingGroupRenamedNoticeUnknown, newName)
            }
            return languageService.format(.messagingGroupRenamedNotice, actor, newName)
        case .groupMemberAdded:
            let addedNames = message.body.trimmingCharacters(in: .whitespacesAndNewlines)
            if message.senderId == currentUserId {
                return languageService.format(.messagingGroupMemberAddedNoticeYou, addedNames)
            }
            if actor.isEmpty {
                return languageService.format(.messagingGroupMemberAddedNoticeUnknown, addedNames)
            }
            return languageService.format(.messagingGroupMemberAddedNotice, actor, addedNames)
        case .groupMemberLeft:
            // Body stores the leaver's display name at write time (survives projection gaps).
            let resolvedActor = actor.isEmpty
                ? GroupSystemNoticePayload.memberLeftDisplayName(message.body)
                : actor
            if message.senderId == currentUserId {
                return languageService.text(.messagingGroupMemberLeftNoticeYou)
            }
            if resolvedActor.isEmpty {
                return languageService.text(.messagingGroupMemberLeftNoticeUnknown)
            }
            return languageService.format(.messagingGroupMemberLeftNotice, resolvedActor)
        case .groupMemberRemoved:
            let removedName = message.body.trimmingCharacters(in: .whitespacesAndNewlines)
            if message.senderId == currentUserId {
                return languageService.format(.messagingGroupMemberRemovedNoticeYouAdmin, removedName)
            }
            if actor.isEmpty {
                return languageService.format(.messagingGroupMemberRemovedNoticeUnknown, removedName)
            }
            return languageService.format(.messagingGroupMemberRemovedNotice, actor, removedName)
        case .groupDeleted:
            if message.senderId == currentUserId {
                return languageService.text(.messagingGroupDeletedNoticeYou)
            }
            if actor.isEmpty {
                return languageService.text(.messagingGroupDeletedNoticeUnknown)
            }
            return languageService.format(.messagingGroupDeletedNotice, actor)
        case .groupAdminTransferred:
            let newAdminName = message.body.trimmingCharacters(in: .whitespacesAndNewlines)
            if message.senderId == currentUserId {
                return languageService.format(.messagingGroupAdminTransferredNoticeYou, newAdminName)
            }
            if actor.isEmpty {
                return languageService.format(.messagingGroupAdminTransferredNoticeUnknown, newAdminName)
            }
            return languageService.format(.messagingGroupAdminTransferredNotice, actor, newAdminName)
        default:
            return message.body
        }
    }
}
