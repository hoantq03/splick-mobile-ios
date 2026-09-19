import SwiftUI
import DesignSystem
import Common
import Localization
import SplickDomain

struct OutgoingFriendRequestsSheet: View {
    @ObservedObject var viewModel: OutgoingFriendRequestsViewModel
    let onProfileTap: (UserSummary, FriendRelationStatus) -> Void
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    LoadingView(message: languageService.text(.friendsOutgoingLoading))
                case .failed(let message):
                    ErrorView(message: message) {
                        Task { await viewModel.load() }
                    }
                case .loaded(let items) where items.isEmpty:
                    EmptyStateView(
                        icon: "paperplane",
                        title: languageService.text(.friendsOutgoingEmptyTitle),
                        message: languageService.text(.friendsOutgoingEmptyMessage)
                    )
                case .loaded:
                    ScrollView {
                        LazyVStack(spacing: SplickTheme.Spacing.xs) {
                            ForEach(viewModel.requests) { request in
                                FriendRowView(
                                    user: request.addressee,
                                    friendStatus: .requestSent,
                                    isProcessing: viewModel.processingRequestIds.contains(request.id),
                                    onProfileTap: {
                                        onProfileTap(request.addressee, .requestSent)
                                    },
                                    onAddFriend: {
                                        Task { await viewModel.cancel(request) }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, SplickTheme.Spacing.md)
                        .padding(.bottom, SplickTheme.Spacing.md)
                    }
                }
            }
            .navigationTitle(languageService.text(.friendsOutgoingTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.friendsClose)) { dismiss() }
                }
            }
            .alert(languageService.text(.friendsOutgoingTitle), isPresented: Binding(
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
