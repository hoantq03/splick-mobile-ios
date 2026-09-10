import SwiftUI
import DesignSystem
import Common
import Localization
import SplickDomain

struct PeopleYouMayKnowSheet: View {
    @ObservedObject var viewModel: PeopleYouMayKnowViewModel
    let currentUserId: UUID?
    let onProfileTap: (UserSummary, FriendRelationStatus) -> Void
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    LoadingView(message: languageService.text(.friendsPeopleYouMayKnowLoading))
                case .failed(let message):
                    ErrorView(message: message) {
                        Task { await viewModel.load() }
                    }
                case .loaded(let items) where items.isEmpty:
                    EmptyStateView(
                        icon: "person.2.circle",
                        title: languageService.text(.friendsPeopleYouMayKnowEmptyTitle),
                        message: languageService.text(.friendsPeopleYouMayKnowEmptyMessage)
                    )
                case .loaded:
                    ScrollView {
                        LazyVStack(spacing: SplickTheme.Spacing.xs) {
                            ForEach(viewModel.suggestions) { suggestion in
                                let result = suggestion.asSearchResult(
                                    subtitle: sharedGroupSubtitle(for: suggestion.sharedGroupName)
                                )
                                FriendRowView(
                                    user: result.user,
                                    friendStatus: result.friendStatus,
                                    isProcessing: viewModel.processingUserIds.contains(suggestion.user.id),
                                    onProfileTap: {
                                        onProfileTap(suggestion.user, suggestion.friendStatus)
                                    },
                                    onAddFriend: {
                                        Task { await viewModel.sendFriendRequest(to: suggestion) }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, SplickTheme.Spacing.md)
                        .padding(.bottom, SplickTheme.Spacing.md)
                    }
                }
            }
            .navigationTitle(languageService.text(.friendsPeopleYouMayKnowTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.friendsClose)) { dismiss() }
                }
            }
            .alert(languageService.text(.friendsPeopleYouMayKnowTitle), isPresented: Binding(
                get: { viewModel.alertMessage != nil },
                set: { if !$0 { viewModel.alertMessage = nil } }
            )) {
                Button(languageService.text(.commonOK), role: .cancel) { viewModel.alertMessage = nil }
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
            .task { await viewModel.load(currentUserId: currentUserId) }
        }
    }

    private func sharedGroupSubtitle(for groupName: String?) -> String? {
        guard let groupName, !groupName.isEmpty else { return nil }
        return String(format: languageService.text(.friendsPeopleYouMayKnowSharedGroup), groupName)
    }
}
