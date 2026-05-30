import SwiftUI
import DesignSystem
import Common
import Localization

struct OutgoingFriendRequestsSheet: View {
    @ObservedObject var viewModel: OutgoingFriendRequestsViewModel
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
                                OutgoingFriendRequestRowView(
                                    request: request,
                                    isProcessing: viewModel.processingRequestIds.contains(request.id),
                                    onCancel: { Task { await viewModel.cancel(request) } }
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

private struct OutgoingFriendRequestRowView: View {
    @EnvironmentObject private var languageService: LanguageService
    let request: OutgoingFriendRequest
    let isProcessing: Bool
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            AvatarView(
                imageURL: request.addressee.avatarURL,
                name: request.addressee.displayName,
                size: .medium
            )

            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                Text(request.addressee.displayName)
                    .font(SplickTheme.Typography.headline)
                Text("@\(request.addressee.username)")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }

            Spacer(minLength: SplickTheme.Spacing.xs)

            if isProcessing {
                SplickSpinner(size: .medium)
            } else {
                Button(languageService.text(.friendsCancel), action: onCancel)
                    .font(SplickTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .buttonStyle(.plain)
            }
        }
        .splickCard(padding: SplickTheme.Spacing.sm)
    }
}
