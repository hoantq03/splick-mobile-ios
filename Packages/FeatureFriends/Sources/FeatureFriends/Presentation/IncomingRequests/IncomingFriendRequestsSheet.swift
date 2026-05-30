import SwiftUI
import DesignSystem
import Common
import Localization

struct IncomingFriendRequestsSheet: View {
    @ObservedObject var viewModel: IncomingFriendRequestsViewModel
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
                                IncomingFriendRequestRowView(
                                    request: request,
                                    isProcessing: viewModel.processingRequestIds.contains(request.id),
                                    onAccept: { Task { await viewModel.accept(request) } },
                                    onReject: { Task { await viewModel.reject(request) } }
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

private struct IncomingFriendRequestRowView: View {
    @EnvironmentObject private var languageService: LanguageService
    let request: IncomingFriendRequest
    let isProcessing: Bool
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            AvatarView(
                imageURL: request.requester.avatarURL,
                name: request.requester.displayName,
                size: .medium
            )

            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                Text(request.requester.displayName)
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                Text("@\(request.requester.username)")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                if let message = request.message, !message.isEmpty {
                    Text(message)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: SplickTheme.Spacing.xs)

            if isProcessing {
                SplickSpinner(size: .medium)
            } else {
                VStack(spacing: SplickTheme.Spacing.xxxs) {
                    Button(languageService.text(.friendsAccept), action: onAccept)
                        .font(SplickTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, SplickTheme.Spacing.xs)
                        .padding(.vertical, SplickTheme.Spacing.xxxs)
                        .background(SplickTheme.Colors.primaryGradientStart)
                        .clipShape(Capsule())

                    Button(languageService.text(.friendsReject), action: onReject)
                        .font(SplickTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .splickCard(padding: SplickTheme.Spacing.sm)
    }
}
