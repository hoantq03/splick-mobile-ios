import SwiftUI
import DesignSystem
import Common
import SplickDomain

struct InviteFriendsToGroupSheet: View {
    @StateObject private var viewModel: InviteFriendsToGroupViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        groupId: UUID,
        existingMemberIds: Set<UUID>,
        currentUserId: UUID?,
        searchUsersUseCase: SearchUsersUseCaseProtocol,
        addFriendUseCase: AddFriendUseCaseProtocol,
        inviteFriendsUseCase: InviteFriendsToGroupUseCaseProtocol,
        onInvited: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: InviteFriendsToGroupViewModel(
                groupId: groupId,
                existingMemberIds: existingMemberIds,
                currentUserId: currentUserId,
                searchUsersUseCase: searchUsersUseCase,
                addFriendUseCase: addFriendUseCase,
                inviteFriendsUseCase: inviteFriendsUseCase,
                onInvited: onInvited
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, SplickTheme.Spacing.md)
                    .padding(.vertical, SplickTheme.Spacing.sm)

                Group {
                    if viewModel.isSearching {
                        searchResultsContent
                    } else {
                        EmptyStateView(
                            icon: "magnifyingglass",
                            title: "Tìm người dùng",
                            message: "Nhập username để mời vào nhóm. Chỉ bạn bè mới được thêm thành công."
                        )
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
                    .disabled(viewModel.selectedIds.isEmpty || viewModel.state == .submitting)
                }
            }
            .onChange(of: viewModel.searchQuery) { newValue in
                viewModel.onSearchQueryChanged(newValue)
            }
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

    private var searchField: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            TextField("Tìm theo username", text: $viewModel.searchQuery)
                .font(SplickTheme.Typography.callout)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(Capsule(style: .continuous))
    }

    @ViewBuilder
    private var searchResultsContent: some View {
        switch viewModel.searchState {
        case .idle, .loading:
            LoadingView(message: "Đang tìm...")
        case .failed(let message):
            ErrorView(message: message) {
                viewModel.onSearchQueryChanged(viewModel.searchQuery)
            }
        case .loaded(let results) where results.isEmpty:
            EmptyStateView(
                icon: "magnifyingglass",
                title: "Không tìm thấy",
                message: "Thử username khác hoặc người này đã trong nhóm."
            )
        case .loaded:
            ScrollView {
                LazyVStack(spacing: SplickTheme.Spacing.xs) {
                    ForEach(viewModel.searchResults) { result in
                        inviteRow(for: result)
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
                .padding(.bottom, SplickTheme.Spacing.md)
            }
        }
    }

    private func inviteRow(for result: UserSearchResult) -> some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            FriendRowView(
                user: result.user,
                friendStatus: result.friendStatus,
                isSendingRequest: viewModel.sendingFriendRequestUserIds.contains(result.user.id),
                onAddFriend: {
                    Task { await viewModel.sendFriendRequest(to: result) }
                }
            )

            Button {
                viewModel.toggleSelection(result.user.id)
            } label: {
                Image(systemName: viewModel.selectedIds.contains(result.user.id)
                      ? "checkmark.circle.fill"
                      : "circle")
                    .font(.title3)
                    .foregroundStyle(
                        viewModel.selectedIds.contains(result.user.id)
                            ? SplickTheme.Colors.primaryGradientStart
                            : SplickTheme.Colors.textTertiary
                    )
            }
            .buttonStyle(.plain)
            .padding(.trailing, SplickTheme.Spacing.sm)
        }
    }
}
