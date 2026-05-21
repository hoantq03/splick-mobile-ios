import SwiftUI
import DesignSystem
import SplickDomain

struct InviteFriendsToGroupSheet: View {
    @StateObject private var viewModel: InviteFriendsToGroupViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        groupId: UUID,
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol,
        inviteFriendsUseCase: InviteFriendsToGroupUseCaseProtocol,
        onInvited: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: InviteFriendsToGroupViewModel(
                groupId: groupId,
                fetchMyFriendsUseCase: fetchMyFriendsUseCase,
                inviteFriendsUseCase: inviteFriendsUseCase,
                onInvited: onInvited
            )
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    LoadingView(message: "Đang tải danh sách bạn...")
                case .failed(let message):
                    ErrorView(message: message) {
                        Task { await viewModel.load() }
                    }
                case .loaded, .submitting:
                    if viewModel.friends.isEmpty {
                        EmptyStateView(
                            icon: "person.2",
                            title: "Chưa có bạn bè",
                            message: "Kết bạn trước khi mời vào nhóm."
                        )
                    } else {
                        friendList
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SplickTheme.Colors.background)
            .navigationTitle("Thêm thành viên")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Mời") {
                        Task { await viewModel.submit() }
                    }
                    .disabled(
                        viewModel.selectedIds.isEmpty
                            || viewModel.state == .submitting
                            || viewModel.state == .loading
                    )
                }
            }
            .task { await viewModel.load() }
            .alert("Lỗi", isPresented: Binding(
                get: { viewModel.alertMessage != nil },
                set: { if !$0 { viewModel.alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
            .alert("Thành công", isPresented: Binding(
                get: { viewModel.successMessage != nil },
                set: { if !$0 { viewModel.successMessage = nil; dismiss() } }
            )) {
                Button("OK", role: .cancel) { dismiss() }
            } message: {
                Text(viewModel.successMessage ?? "")
            }
        }
    }

    private var friendList: some View {
        ScrollView {
            LazyVStack(spacing: SplickTheme.Spacing.xs) {
                ForEach(viewModel.friends) { friend in
                    Button {
                        viewModel.toggleSelection(friend.id)
                    } label: {
                        HStack(spacing: SplickTheme.Spacing.sm) {
                            AvatarView(imageURL: friend.avatarURL, name: friend.displayName, size: .medium)

                            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                                Text(friend.displayName)
                                    .font(SplickTheme.Typography.headline)
                                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                                Text("@\(friend.username)")
                                    .font(SplickTheme.Typography.caption)
                                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                            }

                            Spacer()

                            Image(systemName: viewModel.selectedIds.contains(friend.id)
                                  ? "checkmark.circle.fill"
                                  : "circle")
                                .font(.title3)
                                .foregroundStyle(
                                    viewModel.selectedIds.contains(friend.id)
                                        ? SplickTheme.Colors.primaryGradientStart
                                        : SplickTheme.Colors.textTertiary
                                )
                        }
                        .splickCard(padding: SplickTheme.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(SplickTheme.Spacing.md)
        }
    }
}
