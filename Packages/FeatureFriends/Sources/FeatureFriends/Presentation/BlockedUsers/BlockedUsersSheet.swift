import SwiftUI
import DesignSystem
import Common
import Localization

struct BlockedUsersSheet: View {
    @ObservedObject var viewModel: BlockedUsersViewModel
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
                                HStack(spacing: SplickTheme.Spacing.sm) {
                                    FriendRowView(user: blocked.user)
                                    Button {
                                        Task { await viewModel.unblock(blocked) }
                                    } label: {
                                        Group {
                                            if viewModel.processingUserIds.contains(blocked.user.id) {
                                                SplickSpinner(size: .small)
                                                    .controlSize(.small)
                                            } else {
                                                Text(languageService.text(.friendsUnblock))
                                                    .font(SplickTheme.Typography.caption.weight(.semibold))
                                            }
                                        }
                                        .frame(minWidth: 72)
                                        .padding(.horizontal, SplickTheme.Spacing.xs)
                                        .padding(.vertical, SplickTheme.Spacing.xxxs)
                                        .background(SplickTheme.Colors.secondaryBackground)
                                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(viewModel.processingUserIds.contains(blocked.user.id))
                                }
                                .splickCard(padding: SplickTheme.Spacing.sm)
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
