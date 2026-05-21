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

    private let generateMyQrUseCase: GenerateMyQrUseCaseProtocol

    public init(
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol,
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol,
        searchUsersUseCase: SearchUsersUseCaseProtocol,
        generateMyQrUseCase: GenerateMyQrUseCaseProtocol,
        addFriendUseCase: AddFriendUseCaseProtocol,
        joinGroupUseCase: JoinGroupUseCaseProtocol
    ) {
        let rootVM = FriendsRootViewModel(
            fetchMyFriendsUseCase: fetchMyFriendsUseCase,
            fetchMyGroupsUseCase: fetchMyGroupsUseCase,
            searchUsersUseCase: searchUsersUseCase
        )
        self.generateMyQrUseCase = generateMyQrUseCase
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
                if viewModel.segment == .friends {
                    friendsTopBar
                }

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
                        if viewModel.isSearching {
                            searchResultsContent
                        } else {
                            friendsContent
                        }
                    case .groups:
                        groupsContent
                    }
                }
            }
            .navigationTitle("Friends")
            .onChange(of: viewModel.searchQuery) { newValue in
                viewModel.onSearchQueryChanged(newValue)
            }
            .onChange(of: viewModel.segment) { segment in
                guard segment == .groups else { return }
                viewModel.searchQuery = ""
                viewModel.onSearchQueryChanged("")
            }
            .splickProfileToolbar()
            .toolbar {
                if viewModel.segment == .groups {
                    toolbarAddMenu
                }
            }
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
                        avatarURL: user.avatarURL,
                        generateMyQrUseCase: generateMyQrUseCase
                    )
                }
            }
        }
        .onFirstAppear {
            Task { await viewModel.load() }
        }
    }

    private var friendsTopBar: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            friendsSearchField
            addMenuButton
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.bottom, SplickTheme.Spacing.sm)
    }

    private var friendsSearchField: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            TextField("Search by username", text: $viewModel.searchQuery)
                .font(SplickTheme.Typography.callout)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(Capsule(style: .continuous))
    }

    @ToolbarContentBuilder
    private var toolbarAddMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            addMenuButton
        }
    }

    private var addMenuButton: some View {
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
                .font(.system(size: 28))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add")
    }

    @ViewBuilder
    private var searchResultsContent: some View {
        switch viewModel.searchState {
        case .idle, .loading:
            LoadingView(message: "Searching...")
        case .failed(let message):
            ErrorView(message: message) {
                viewModel.onSearchQueryChanged(viewModel.searchQuery)
            }
        case .loaded(let results) where results.isEmpty:
            EmptyStateView(
                icon: "magnifyingglass",
                title: "No users found",
                message: "Try another username."
            )
        case .loaded:
            ScrollView {
                LazyVStack(spacing: SplickTheme.Spacing.xs) {
                    ForEach(viewModel.searchResults) { user in
                        Button {
                            profileRoute = UserProfileRoute(user: user)
                        } label: {
                            FriendRowView(user: user)
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
