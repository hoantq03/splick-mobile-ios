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
    @StateObject private var incomingRequestsViewModel: IncomingFriendRequestsViewModel
    @Environment(\.currentUserSummary) private var currentUserSummary

    @State private var showAddFriend = false
    @State private var showJoinGroup = false
    @State private var showCreateGroup = false
    @State private var showAddFriendQR = false
    @State private var showJoinGroupQR = false
    @State private var showIncomingRequests = false
    @State private var profileRoute: UserProfileRoute?

    private let generateMyQrUseCase: GenerateMyQrUseCaseProtocol
    private let createGroupUseCase: CreateGroupUseCaseProtocol

    public init(
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol,
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol,
        searchUsersUseCase: SearchUsersUseCaseProtocol,
        generateMyQrUseCase: GenerateMyQrUseCaseProtocol,
        addFriendUseCase: AddFriendUseCaseProtocol,
        fetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCaseProtocol,
        acceptFriendRequestUseCase: AcceptFriendRequestUseCaseProtocol,
        rejectFriendRequestUseCase: RejectFriendRequestUseCaseProtocol,
        joinGroupUseCase: JoinGroupUseCaseProtocol,
        createGroupUseCase: CreateGroupUseCaseProtocol
    ) {
        let rootVM = FriendsRootViewModel(
            fetchMyFriendsUseCase: fetchMyFriendsUseCase,
            fetchMyGroupsUseCase: fetchMyGroupsUseCase,
            searchUsersUseCase: searchUsersUseCase,
            addFriendUseCase: addFriendUseCase,
            fetchIncomingFriendRequestsUseCase: fetchIncomingFriendRequestsUseCase
        )
        self.generateMyQrUseCase = generateMyQrUseCase
        self.createGroupUseCase = createGroupUseCase
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
        _incomingRequestsViewModel = StateObject(
            wrappedValue: IncomingFriendRequestsViewModel(
                fetchIncomingUseCase: fetchIncomingFriendRequestsUseCase,
                acceptUseCase: acceptFriendRequestUseCase,
                rejectUseCase: rejectFriendRequestUseCase,
                onFriendshipChanged: { rootVM.onFriendAdded() }
            )
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
                            VStack(spacing: SplickTheme.Spacing.xs) {
                                incomingRequestsBanner
                                friendsContent
                            }
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
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupSheet(
                    viewModel: CreateGroupViewModel(createGroupUseCase: createGroupUseCase) { group in
                        viewModel.onGroupCreated(group)
                        showCreateGroup = false
                    }
                )
            }
            .sheet(isPresented: $showIncomingRequests, onDismiss: {
                Task { await viewModel.refreshIncomingRequestCount() }
            }) {
                IncomingFriendRequestsSheet(viewModel: incomingRequestsViewModel)
            }
            .sheet(isPresented: $showAddFriendQR) {
                if let user = currentUserSummary {
                    QRScannerSheet(
                        mode: .addFriend,
                        onScan: { code in
                            Task { await addFriendViewModel.addFromQR(code) }
                        },
                        myQrContext: QRScannerMyQrContext(
                            username: user.username,
                            displayName: user.displayName,
                            avatarURL: user.avatarURL,
                            generateMyQrUseCase: generateMyQrUseCase
                        )
                    )
                }
            }
            .sheet(isPresented: $showJoinGroupQR) {
                QRScannerSheet(mode: .joinGroup) { code in
                    Task { await joinGroupViewModel.joinFromQR(code) }
                }
            }
        }
        .alert("Friends", isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.alertMessage = nil }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .onFirstAppear {
            Task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private var incomingRequestsBanner: some View {
        if viewModel.incomingRequestCount > 0 {
            Button {
                showIncomingRequests = true
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle.badge.plus")
                    Text("Lời mời kết bạn (\(viewModel.incomingRequestCount))")
                        .font(SplickTheme.Typography.callout.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                .padding(SplickTheme.Spacing.sm)
                .background(SplickTheme.Colors.primaryGradientStart.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.top, SplickTheme.Spacing.xs)
        }
    }

    private func actionForSearchResult(_ result: UserSearchResult) -> (() -> Void)? {
        switch result.friendStatus {
        case .none:
            return { Task { await viewModel.sendFriendRequest(to: result) } }
        case .requestReceived:
            return { showIncomingRequests = true }
        case .friends, .requestSent, .blocked:
            return nil
        }
    }

    private var friendsTopBar: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            friendsSearchField
            scanQrButton
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

    private var scanQrButton: some View {
        Button {
            showAddFriendQR = true
        } label: {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                .frame(width: 44, height: 44)
                .background(SplickTheme.Colors.secondaryBackground)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Quét mã QR")
    }

    private var addMenuButton: some View {
        Menu {
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

            Button {
                showCreateGroup = true
            } label: {
                Label("Tạo nhóm", systemImage: "plus.circle")
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
                    ForEach(viewModel.searchResults) { result in
                        FriendRowView(
                            user: result.user,
                            friendStatus: result.friendStatus,
                            isSendingRequest: viewModel.sendingFriendRequestUserIds.contains(result.user.id),
                            onProfileTap: {
                                profileRoute = UserProfileRoute(user: result.user)
                            },
                            onAddFriend: actionForSearchResult(result)
                        )
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
                title: "Chưa có nhóm",
                message: "Tạo nhóm mới hoặc tham gia bằng mã mời / QR.",
                actionTitle: "Tạo nhóm"
            ) {
                showCreateGroup = true
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
