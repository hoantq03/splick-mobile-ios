import SwiftUI
import DesignSystem
import Common
import Localization
import SplickDomain

struct BlockedUsersSheet: View {
    @ObservedObject var viewModel: BlockedUsersViewModel
    let onProfileTap: (UserSummary, FriendRelationStatus) -> Void
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    LoadingView(message: languageService.text(.friendsBlockedLoading))
                case .failed(let message):
                    ErrorView(message: message) {
                        Task { await viewModel.load() }
                    }
                case .loaded where viewModel.blockedUsers.isEmpty:
                    EmptyStateView(
                        icon: "hand.raised",
                        title: languageService.text(.friendsBlockedEmptyTitle),
                        message: languageService.text(.friendsBlockedEmptyMessage)
                    )
                case .loaded:
                    ScrollView {
                        LazyVStack(spacing: SplickTheme.Spacing.xs) {
                            ForEach(viewModel.blockedUsers) { blocked in
                                FriendRowView(
                                    user: blocked.user,
                                    friendStatus: .blocked,
                                    isProcessing: viewModel.processingUserIds.contains(blocked.user.id),
                                    onProfileTap: {
                                        onProfileTap(blocked.user, .blocked)
                                    },
                                    onUnblock: {
                                        Task { await viewModel.unblock(blocked) }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, SplickTheme.Spacing.md)
                        .padding(.bottom, SplickTheme.Spacing.md)
                    }
                }
            }
            .navigationTitle(languageService.text(.friendsBlockedTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.friendsClose)) { dismiss() }
                }
            }
            .alert(languageService.text(.friendsBlockedTitle), isPresented: Binding(
                get: { viewModel.alertMessage != nil },
                set: { if !$0 { viewModel.alertMessage = nil } }
            )) {
                Button(languageService.text(.commonOK), role: .cancel) { viewModel.alertMessage = nil }
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
            .task { await viewModel.load() }
        }
    }
}
