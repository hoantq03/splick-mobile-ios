import SwiftUI
import DesignSystem
import Common
import SplickDomain

private struct UserProfileRoute: Identifiable {
    let user: UserSummary
    var id: UUID { user.id }
}


public struct FriendsRootView: View {
    @StateObject private var viewModel: FriendsRootViewModel
    @StateObject private var addFriendViewModel: AddFriendViewModel
    @StateObject private var joinGroupViewModel: JoinGroupViewModel
    @Environment(\.currentUserSummary) private var currentUserSummary

    @State private var showAddFriend = false
    @State private var showJoinGroup = false
    @State private var showAddFriendQR = false
    @State private var showJoinGroupQR = false
    @State private var showMyQR = false
    @State private var profileRoute: UserProfileRoute?

    public init(
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol,
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol,
        addFriendUseCase: AddFriendUseCaseProtocol,
        joinGroupUseCase: JoinGroupUseCaseProtocol
    ) {
        let rootVM = FriendsRootViewModel(
            fetchMyFriendsUseCase: fetchMyFriendsUseCase,
            fetchMyGroupsUseCase: fetchMyGroupsUseCase
        )
        _viewModel = StateObject(wrappedValue: rootVM)
        _addFriendViewModel = StateObject(
            wrappedValue: AddFriendViewModel(addFriendUseCase: addFriendUseCase) {
                rootVM.onFriendAdded()
            }
        )
        _joinGroupViewModel = StateObject(
            wrappedValue: JoinGroupViewModel(joinGroupUseCase: joinGroupUseCase) {
                rootVM.onGroupJoined()
            }
        )
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $viewModel.segment) {
                    ForEach(FriendsRootViewModel.Segment.allCases, id: \.self) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, SplickTheme.Spacing.md)
                .padding(.vertical, SplickTheme.Spacing.sm)

                Group {
                    switch viewModel.segment {
                    case .friends:
                        friendsContent
                    case .groups:
                        groupsContent
                    }
                }
            }
            .navigationTitle("Friends")
            .splickProfileToolbar()
            .toolbar { toolbarContent }
            .refreshable { await viewModel.refresh() }
            .navigationDestination(for: UUID.self) { groupId in
                if let group = viewModel.groups.first(where: { $0.id == groupId }) {
                    GroupDetailView(group: group) { user in
                        profileRoute = UserProfileRoute(user: user)
                    }
                }
            }
            .sheet(item: $profileRoute) { route in
                FriendUserProfileView(user: route.user)
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendSheet(viewModel: addFriendViewModel)
            }
            .sheet(isPresented: $showJoinGroup) {
                JoinGroupSheet(viewModel: joinGroupViewModel)
            }
            .sheet(isPresented: $showAddFriendQR) {
                QRScannerSheet(mode: .addFriend) { code in
                    Task { await addFriendViewModel.addFromQR(code) }
                }
            }
            .sheet(isPresented: $showJoinGroupQR) {
                QRScannerSheet(mode: .joinGroup) { code in
                    Task { await joinGroupViewModel.joinFromQR(code) }
                }
            }
            .sheet(isPresented: $showMyQR) {
                if let user = currentUserSummary {
                    MyQRSheet(
                        username: user.username,
                        displayName: user.displayName,
                        avatarURL: user.avatarURL
                    )
                }
            }
        }
        .onFirstAppear {
            Task { await viewModel.load() }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    showMyQR = true
                } label: {
                    Label("Mã QR của tôi", systemImage: "qrcode")
                }

                Divider()

                Button {
                    showAddFriend = true
                } label: {
                    Label("Add friend by username", systemImage: "person.badge.plus")
                }

                Button {
                    showAddFriendQR = true
                } label: {
                    Label("Add friend by QR", systemImage: "qrcode.viewfinder")
                }

                Divider()

                Button {
                    showJoinGroup = true
                } label: {
                    Label("Join group by code", systemImage: "person.3.fill")
                }

                Button {
                    showJoinGroupQR = true
                } label: {
                    Label("Join group by QR", systemImage: "qrcode")
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
            }
        }
    }

    @ViewBuilder
    private var friendsContent: some View {
        switch viewModel.friendsState {
        case .idle, .loading where viewModel.friends.isEmpty:
            LoadingView(message: "Loading friends...")
        case .failed(let message) where viewModel.friends.isEmpty:
            ErrorView(message: message) {
                Task { await viewModel.loadFriends(isPullToRefresh: false) }
            }
        case .loaded where viewModel.friends.isEmpty:
            EmptyStateView(
                icon: "person.2",
                title: "No friends yet",
                message: "Add friends by username or scan their QR code.",
                actionTitle: "Add friend"
            ) {
                showAddFriend = true
            }
        default:
            ScrollView {
                LazyVStack(spacing: SplickTheme.Spacing.xs) {
                    ForEach(viewModel.friends) { friend in
                        Button {
                            profileRoute = UserProfileRoute(user: friend)
                        } label: {
                            FriendRowView(user: friend)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
                .padding(.bottom, SplickTheme.Spacing.md)
            }
            .tabBarHideOnScroll()
        }
    }

    @ViewBuilder
    private var groupsContent: some View {
        switch viewModel.groupsState {
        case .idle, .loading where viewModel.groups.isEmpty:
            LoadingView(message: "Loading groups...")
        case .failed(let message) where viewModel.groups.isEmpty:
            ErrorView(message: message) {
                Task { await viewModel.loadGroups(isPullToRefresh: false) }
            }
        case .loaded where viewModel.groups.isEmpty:
            EmptyStateView(
                icon: "person.3",
                title: "No groups yet",
                message: "Join a group with an invite code or scan a group QR code.",
                actionTitle: "Join group"
            ) {
                showJoinGroup = true
            }
        default:
            ScrollView {
                LazyVStack(spacing: SplickTheme.Spacing.xs) {
                    ForEach(viewModel.groups) { group in
                        NavigationLink(value: group.id) {
                            GroupRowView(group: group)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
                .padding(.bottom, SplickTheme.Spacing.md)
            }
            .tabBarHideOnScroll()
        }
    }
}
