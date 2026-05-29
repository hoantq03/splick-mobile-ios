import SwiftUI
import DesignSystem
import Common

struct OutgoingFriendRequestsSheet: View {
    @ObservedObject var viewModel: OutgoingFriendRequestsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    LoadingView(message: "Loading sent requests...")
                case .failed(let message):
                    ErrorView(message: message) {
                        Task { await viewModel.load() }
                    }
                case .loaded(let items) where items.isEmpty:
                    EmptyStateView(
                        icon: "paperplane",
                        title: "No sent requests",
                        message: "Friend requests you send will appear here until they accept or you cancel."
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
            .navigationTitle("Sent requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Sent requests", isPresented: Binding(
                get: { viewModel.alertMessage != nil },
                set: { if !$0 { viewModel.alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) { viewModel.alertMessage = nil }
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
            .task { await viewModel.load() }
        }
    }
}

private struct OutgoingFriendRequestRowView: View {
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
                Button("Hủy", action: onCancel)
                    .font(SplickTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .buttonStyle(.plain)
            }
        }
        .splickCard(padding: SplickTheme.Spacing.sm)
    }
}
