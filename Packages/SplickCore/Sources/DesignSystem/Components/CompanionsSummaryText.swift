import SwiftUI
import Localization
import SplickDomain

/// Feed/post companion line: "Out with **Name** and N others", or "Out with **you**..." when tagged.
public struct CompanionsSummaryText: View {
    @EnvironmentObject private var languageService: LanguageService

    private let companions: [UserSummary]
    private let groupName: String?
    private let currentUserId: UUID?
    private let font: Font
    private let color: Color

    public init(
        companions: [UserSummary],
        groupName: String?,
        currentUserId: UUID?,
        font: Font = .system(size: 11),
        color: Color = SplickTheme.Colors.textSecondary
    ) {
        self.companions = companions
        self.groupName = groupName
        self.currentUserId = currentUserId
        self.font = font
        self.color = color
    }

    public var body: some View {
        assembled
            .font(font)
            .foregroundStyle(color)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }

    private var assembled: Text {
        let prefix = Text(languageService.text(.feedCompanionsWith) + " ")

        if let groupName, !groupName.isEmpty {
            return prefix + Text(groupName).fontWeight(.semibold)
        }

        let taggedSelf = currentUserId.map { id in companions.contains { $0.id == id } } ?? false
        if taggedSelf {
            let you = Text(languageService.text(.feedCompanionsYou)).fontWeight(.bold)
            if companions.count <= 1 {
                return prefix + you
            }
            let others = companions.count - 1
            return prefix + you + Text(languageService.format(.feedCompanionsAndOthers, others))
        }

        let maxNamed = 1
        if companions.count <= maxNamed {
            let names = companions.map(\.displayName).joined(separator: ", ")
            return prefix + Text(names).fontWeight(.semibold)
        }

        let first = companions.prefix(maxNamed).map(\.displayName).joined(separator: ", ")
        let others = companions.count - maxNamed
        return prefix + Text(first).fontWeight(.semibold)
            + Text(languageService.format(.feedCompanionsAndOthers, others))
    }
}
