import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain

struct InboxSearchLanding: View {
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var presenceStore: PresenceStore

    let recentPeople: [UserSummary]
    let suggestions: [UserSummary]
    let onSelect: (UserSummary) -> Void
    let onRemoveRecent: (UUID) -> Void

    @State private var isEditingRecent = false
    @State private var appeared = false

    private static let avatarSize: CGFloat = 64
    private static let labelWidth: CGFloat = 72

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
                if !recentPeople.isEmpty {
                    recentSection
                }
                if !orderedSuggestions.isEmpty {
                    suggestionsSection
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.top, SplickTheme.Spacing.sm)
            .padding(.bottom, SplickTabBarMetrics.floatingClearance + SplickTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SplickTheme.Colors.background)
        .onAppear {
            withAnimation(MessagingSearchChromeAnimation.landingSpring) {
                appeared = true
            }
        }
    }

    private var orderedSuggestions: [UserSummary] {
        let recentIds = Set(recentPeople.map(\.id))
        let candidates = suggestions.filter { !recentIds.contains($0.id) }
        return InboxFriendOrdering.sorted(candidates, presence: presenceStore.states)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            HStack {
                Text(languageService.text(.searchHistoryTitle))
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                Spacer()
                Button(languageService.text(isEditingRecent ? .commonDone : .messagingSearchEdit)) {
                    isEditingRecent.toggle()
                }
                .font(SplickTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: SplickTheme.Spacing.md) {
                    ForEach(Array(recentPeople.enumerated()), id: \.element.id) { index, person in
                        recentPerson(person)
                            .bounceIn(appeared: appeared, index: index)
                    }
                }
            }
        }
    }

    private func recentPerson(_ person: UserSummary) -> some View {
        let presence = resolvedPresence(for: person.id)
        return Button {
            guard !isEditingRecent else { return }
            onSelect(person)
        } label: {
            VStack(spacing: SplickTheme.Spacing.xxxs) {
                ZStack(alignment: .topTrailing) {
                    ConversationListAvatar(
                        imageURL: person.avatarURL,
                        name: person.preferredName,
                        userId: person.id,
                        isOnline: PresenceDisplayPolicy.shouldShowOnlineIndicator(isOnline: presence.isOnline),
                        lastSeenLabel: nil
                    )
                    .scaleEffect(Self.avatarSize / 48)
                    .frame(width: Self.avatarSize, height: Self.avatarSize)

                    if isEditingRecent {
                        Button {
                            onRemoveRecent(person.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, SplickTheme.Colors.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .offset(x: 4, y: -4)
                        .accessibilityLabel(languageService.text(.commonClear))
                    }
                }

                Text(person.preferredName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: Self.labelWidth)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(person.preferredName)
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            Text(languageService.text(.messagingSearchSuggestions))
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(SplickTheme.Colors.textPrimary)

            ForEach(Array(orderedSuggestions.enumerated()), id: \.element.id) { index, person in
                let presence = resolvedPresence(for: person.id)
                Button {
                    onSelect(person)
                } label: {
                    HStack(spacing: SplickTheme.Spacing.sm) {
                        ConversationListAvatar(
                            imageURL: person.avatarURL,
                            name: person.preferredName,
                            userId: person.id,
                            isOnline: PresenceDisplayPolicy.shouldShowOnlineIndicator(isOnline: presence.isOnline),
                            lastSeenLabel: PresenceDisplayPolicy.compactLastSeenLabel(
                                isOnline: presence.isOnline,
                                lastSeenAt: presence.lastSeenAt,
                                appLocale: languageService.locale
                            )
                        )
                        Text(person.preferredName)
                            .font(SplickTheme.Typography.headline)
                            .foregroundStyle(SplickTheme.Colors.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, SplickTheme.Spacing.xs)
                }
                .buttonStyle(.plain)
                .bounceIn(appeared: appeared, index: index + 1)
            }
        }
    }

    private func resolvedPresence(for userId: UUID) -> (isOnline: Bool, lastSeenAt: Date?) {
        guard let state = presenceStore.state(for: userId) else {
            return (false, nil)
        }
        return (state.isOnline, state.lastSeenAt)
    }
}

private extension View {
    func bounceIn(appeared: Bool, index: Int) -> some View {
        scaleEffect(appeared ? 1 : 0.78, anchor: .center)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .animation(MessagingSearchChromeAnimation.landingItemSpring(index: index), value: appeared)
    }
}
