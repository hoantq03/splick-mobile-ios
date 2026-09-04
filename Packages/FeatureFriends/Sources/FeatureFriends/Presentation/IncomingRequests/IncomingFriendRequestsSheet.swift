import SwiftUI
import DesignSystem
import Common
import Localization
import SplickDomain

struct IncomingFriendRequestsSheet: View {
    @ObservedObject var viewModel: IncomingFriendRequestsViewModel
    let onProfileTap: (UserSummary, FriendRelationStatus) -> Void
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    LoadingView(message: languageService.text(.friendsIncomingLoading))
                case .failed(let message):
                    ErrorView(message: message) {
                        Task { await viewModel.load() }
                    }
                case .loaded(let items) where items.isEmpty:
                    EmptyStateView(
                        icon: "person.crop.circle.badge.plus",
                        title: languageService.text(.friendsIncomingEmptyTitle),
                        message: languageService.text(.friendsIncomingEmptyMessage)
                    )
                case .loaded:
                    ScrollView {
                        LazyVStack(spacing: SplickTheme.Spacing.xs) {
                            ForEach(viewModel.requests) { request in
                                FriendRowView(
                                    user: request.requester,
                                    friendStatus: .requestReceived,
                                    isProcessing: viewModel.processingRequestIds.contains(request.id),
                                    onProfileTap: {
                                        onProfileTap(request.requester, .requestReceived)
                                    },
                                    onAddFriend: {
                                        Task { await viewModel.accept(request) }
                                    },
                                    onRejectFriend: {
                                        Task { await viewModel.reject(request) }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, SplickTheme.Spacing.md)
                        .padding(.bottom, SplickTheme.Spacing.md)
                    }
                }
            }
            .navigationTitle(languageService.text(.friendsIncomingTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.friendsClose)) { dismiss() }
                }
            }
            .alert(languageService.text(.friendsIncomingTitle), isPresented: Binding(
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
