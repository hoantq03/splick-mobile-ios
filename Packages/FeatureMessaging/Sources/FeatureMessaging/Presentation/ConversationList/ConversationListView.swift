import SwiftUI
import Combine
import Common
import DesignSystem
import Localization
import SplickDomain

import SplickDomain

private struct NewMessageComposePresentation: Identifiable {
    let id = UUID()
    let viewModel: NewMessageComposeViewModel
}

public struct ConversationListView: View {
    @ObservedObject private var viewModel: ConversationListViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @Environment(\.pullToRefreshActive) private var pullToRefreshActive
    @State private var isPullRefreshing = false
    @State private var composePresentation: NewMessageComposePresentation?
    private let onCreateGroup: () -> Void
    private let makeComposeViewModel: () -> NewMessageComposeViewModel
    @Binding private var conversationToOpen: Conversation?

    private var suppressRefreshAnimations: Bool {
        pullToRefreshActive || isPullRefreshing
    }
    @State private var path = NavigationPath()
    @State private var searchDraft = ""
    @State private var scrollTopSignal = 0
    @State private var searchScrollTopSignal = 0
    @State private var refreshController = SplickRefreshController()
    @State private var searchRefreshController = SplickRefreshController()
    @FocusState private var isSearchFocused: Bool
    @State private var showCloseFriendsComingSoon = false

    private var sameTabTapPublisher: AnyPublisher<Void, Never> {
        tabBarScrollState?.sameTabTapSubject.eraseToAnyPublisher()
            ?? Empty().eraseToAnyPublisher()
    }

    private var isSearching: Bool {
        !searchDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public init(
        viewModel: ConversationListViewModel,
        onCreateGroup: @escaping () -> Void = {},
        makeComposeViewModel: @escaping () -> NewMessageComposeViewModel,
        conversationToOpen: Binding<Conversation?> = .constant(nil)
    ) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.onCreateGroup = onCreateGroup
        self.makeComposeViewModel = makeComposeViewModel
        self._conversationToOpen = conversationToOpen
    }

    public var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                messagingSearchBar

                if !isSearching {
                    inboxFilterShortcuts
                }

                ZStack {
                    conversationListContent

                    if isSearching {
                        searchResultsContent
                            .background(SplickTheme.Colors.background)
                            .transition(.opacity)
                    }
                }
            }
            .animation(
                suppressRefreshAnimations ? nil : MessagingSearchChromeAnimation.resultsSpring,
                value: isSearching
            )
            .onPreferenceChange(PullToRefreshActivePreferenceKey.self) { isPullRefreshing = $0 }
            .splickTabScreenHeader(languageService.text(.messagingTitle), showsBell: false)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    composeMenu
                }
            }
            .navigationDestination(for: ChatThreadRoute.self) { route in
                ChatThreadNavigationWrapper(
                    conversation: route.conversation,
                    highlightMessageId: route.highlightMessageId
                )
            }
            .sheet(item: $composePresentation) { presentation in
                NewMessageComposeView(viewModel: presentation.viewModel) { conversation in
                    composePresentation = nil
                    path.append(ChatThreadRoute(conversation: conversation))
                    Task { await viewModel.refresh() }
                }
                .environmentObject(languageService)
            }
        }
        .onChange(of: searchDraft) { newValue in
            viewModel.onSearchQueryChanged(newValue)
        }
        .onChange(of: isSearchFocused) { focused in
            guard !focused, searchDraft.isEmpty else { return }
            viewModel.onSearchQueryChanged("")
        }
        .alert(
            languageService.text(.messagingStartConversationError),
            isPresented: startConversationErrorPresented
        ) {
            Button("OK", role: .cancel) {
                viewModel.clearStartConversationError()
            }
        } message: {
            Text(viewModel.startConversationError ?? "")
        }
        .alert(
            languageService.text(.messagingFilterCloseFriends),
            isPresented: $showCloseFriendsComingSoon
        ) {
            Button(languageService.text(.commonOK), role: .cancel) {}
        } message: {
            Text(languageService.text(.messagingFilterComingSoon))
        }
        .onFirstAppear {
            guard viewModel.conversations.isEmpty else { return }
            Task { await viewModel.load() }
        }
        .onChange(of: conversationToOpen?.id) { _ in
            guard let conversation = conversationToOpen else { return }
            path.append(ChatThreadRoute(conversation: conversation))
            conversationToOpen = nil
            Task { await viewModel.refresh() }
        }
        .onReceive(sameTabTapPublisher) { _ in
            if tabBarScrollState?.isAtTop == true {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if isSearching {
                    searchRefreshController.refresh()
                } else {
                    refreshController.refresh()
                }
            } else if isSearching {
                searchScrollTopSignal += 1
            } else {
                scrollTopSignal += 1
            }
        }
    }

    private var composeMenu: some View {
        Menu {
            Button {
                onCreateGroup()
            } label: {
                Label(
                    languageService.text(.friendsCreateGroup),
                    systemImage: "person.3.fill"
                )
            }

            Button {
                beginNewMessage()
            } label: {
                Label(
                    languageService.text(.messagingNewConversation),
                    systemImage: "square.and.pencil"
                )
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
        }
        .accessibilityLabel(languageService.text(.messagingNewConversation))
    }

    private func beginNewMessage() {
        composePresentation = NewMessageComposePresentation(
            viewModel: makeComposeViewModel()
        )
    }

    private var startConversationErrorPresented: Binding<Bool> {
        Binding(
            get: { viewModel.startConversationError != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearStartConversationError()
                }
            }
        )
    }

    @ViewBuilder
    private var conversationListContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView(message: languageService.text(.messagingLoading))

        case .loaded(let items) where items.isEmpty && viewModel.activeFilter == nil:
            EmptyStateView(
                icon: "bubble.left.and.bubble.right",
                title: languageService.text(.messagingEmptyTitle),
                message: languageService.text(.messagingEmptyMessage)
            )

        case .loaded where viewModel.conversations.isEmpty:
            filterEmptyState

        case .loaded:
            conversationList(viewModel.conversations)

        case .failed(let message):
            ErrorView(message: message) {
                Task { await viewModel.load() }
            }
        }
    }

    @ViewBuilder
    private var searchResultsContent: some View {
        switch viewModel.searchState {
        case .loading where viewModel.searchResults.isEmpty:
            searchResultsPlaceholder(
                message: languageService.text(.messagingSearchLoading),
                showsSpinner: true
            )

        case .failed(let message):
            ErrorView(message: message) {
                viewModel.onSearchQueryChanged(searchDraft)
            }

        case .loaded(let results) where results.isEmpty:
            EmptyStateView(
                icon: "magnifyingglass",
                title: languageService.text(.messagingSearchEmptyTitle),
                message: languageService.text(.messagingSearchEmptyMessage)
            )

        case .idle, .loading, .loaded:
            searchResultsList(viewModel.searchResults)
        }
    }

    private func searchResultsPlaceholder(message: String, showsSpinner: Bool) -> some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            if showsSpinner {
                ProgressView()
            }
            Text(message)
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func searchResultsList(_ results: [MessagingSearchResult]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    Color.clear.frame(height: 0).id("messagingSearchScrollTop")
                    ForEach(results) { result in
                        Button {
                            Task { await openSearchResult(result) }
                        } label: {
                            MessagingSearchResultRowView(
                                result: result,
                                query: viewModel.activeSearchQuery,
                                isStarting: viewModel.isStartingConversation
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isStartingConversation)
                        Divider()
                            .padding(.leading, 56)
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
                .transaction { transaction in
                    if suppressRefreshAnimations {
                        transaction.animation = nil
                    }
                }
            }
            .id("messagingSearchScroll")
            .scrollDismissesKeyboard(.interactively)
            .tabBarHideOnScroll()
            .splickNativeRefreshable(controller: searchRefreshController) {
                await viewModel.refreshSearch(query: searchDraft)
            }
            .onChange(of: searchScrollTopSignal) { _ in
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    proxy.scrollTo("messagingSearchScrollTop", anchor: .top)
                }
            }
        }
    }

    private func dismissSearch() {
        withAnimation(MessagingSearchChromeAnimation.focusSpring) {
            isSearchFocused = false
        }
        searchDraft = ""
        viewModel.onSearchQueryChanged("")
    }

    private func openSearchResult(_ result: MessagingSearchResult) async {
        let route: ChatThreadRoute
        switch result {
        case .user(let user):
            guard let userRoute = await viewModel.startConversation(with: user) else { return }
            route = userRoute
        case .message(let hit):
            route = viewModel.routeForMessageHit(hit)
        }

        withAnimation(MessagingSearchChromeAnimation.focusSpring) {
            isSearchFocused = false
        }
        viewModel.onSearchQueryChanged("")
        searchDraft = ""
        path.append(route)
        await viewModel.refresh()
    }

    @ViewBuilder
    private func conversationList(_ items: [Conversation]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    Color.clear.frame(height: 0).id("messagingScrollTop")
                    ForEach(items) { conversation in
                        Button {
                            path.append(ChatThreadRoute(conversation: conversation))
                        } label: {
                            ConversationRowView(conversation: conversation)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            Task { await viewModel.loadMoreIfNeeded(current: conversation) }
                        }
                        Divider()
                            .padding(.leading, 56)
                    }

                    if viewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding(.vertical, SplickTheme.Spacing.md)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
                .transaction { transaction in
                    if suppressRefreshAnimations {
                        transaction.animation = nil
                    }
                }
            }
            .id("messagingConversationScroll")
            .scrollDismissesKeyboard(.interactively)
            .tabBarHideOnScroll()
            .splickNativeRefreshable(controller: refreshController) {
                await viewModel.refresh()
            }
            .onChange(of: scrollTopSignal) { _ in
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    proxy.scrollTo("messagingScrollTop", anchor: .top)
                }
            }
        }
    }

    private var messagingSearchBar: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            HStack(spacing: SplickTheme.Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)

                TextField(
                    languageService.text(.messagingSearchPlaceholder),
                    text: $searchDraft
                )
                .font(SplickTheme.Typography.callout)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isSearchFocused)

                if viewModel.isRefreshingSearch, !suppressRefreshAnimations {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, SplickTheme.Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(SplickTheme.Colors.secondaryBackground)
            .clipShape(Capsule(style: .continuous))

            if isSearching || isSearchFocused {
                Button(languageService.text(.commonCancel), action: dismissSearch)
                    .font(SplickTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.bottom, SplickTheme.Spacing.sm)
        .animation(
            suppressRefreshAnimations ? nil : MessagingSearchChromeAnimation.focusSpring,
            value: isSearching
        )
        .animation(
            suppressRefreshAnimations ? nil : MessagingSearchChromeAnimation.focusSpring,
            value: isSearchFocused
        )
    }

    private var inboxFilterShortcuts: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SplickTheme.Spacing.sm) {
                inboxFilterShortcut(
                    icon: "person.3.fill",
                    title: languageService.text(.messagingFilterGroups),
                    isHighlighted: viewModel.isFilterActive(.groups),
                    badgeCount: 0
                ) {
                    viewModel.toggleFilter(.groups)
                }

                inboxFilterShortcut(
                    icon: "person.fill",
                    title: languageService.text(.messagingFilterUsers),
                    isHighlighted: viewModel.isFilterActive(.users),
                    badgeCount: 0
                ) {
                    viewModel.toggleFilter(.users)
                }

                inboxFilterShortcut(
                    icon: "envelope.badge.fill",
                    title: languageService.text(.messagingFilterUnread),
                    isHighlighted: viewModel.isFilterActive(.unread),
                    badgeCount: viewModel.unreadConversationCount
                ) {
                    viewModel.toggleFilter(.unread)
                }

                inboxFilterShortcut(
                    icon: "heart.fill",
                    title: languageService.text(.messagingFilterCloseFriends),
                    isHighlighted: false,
                    badgeCount: 0,
                    isDisabled: true
                ) {
                    showCloseFriendsComingSoon = true
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
        }
        .padding(.bottom, SplickTheme.Spacing.sm)
    }

    @ViewBuilder
    private var filterEmptyState: some View {
        let filter = viewModel.activeFilter
        EmptyStateView(
            icon: filterEmptyIcon(for: filter),
            title: filterEmptyTitle(for: filter),
            message: filterEmptyMessage(for: filter)
        )
    }

    private func filterEmptyIcon(for filter: ConversationListViewModel.InboxFilter?) -> String {
        switch filter {
        case .groups: return "person.3"
        case .users: return "person"
        case .unread: return "envelope.open"
        case .closeFriends, .none: return "line.3.horizontal.decrease.circle"
        }
    }

    private func filterEmptyTitle(for filter: ConversationListViewModel.InboxFilter?) -> String {
        switch filter {
        case .groups:
            return languageService.text(.messagingFilterEmptyGroupsTitle)
        case .users:
            return languageService.text(.messagingFilterEmptyUsersTitle)
        case .unread:
            return languageService.text(.messagingFilterEmptyUnreadTitle)
        case .closeFriends, .none:
            return languageService.text(.messagingEmptyTitle)
        }
    }

    private func filterEmptyMessage(for filter: ConversationListViewModel.InboxFilter?) -> String {
        switch filter {
        case .groups:
            return languageService.text(.messagingFilterEmptyGroupsMessage)
        case .users:
            return languageService.text(.messagingFilterEmptyUsersMessage)
        case .unread:
            return languageService.text(.messagingFilterEmptyUnreadMessage)
        case .closeFriends, .none:
            return languageService.text(.messagingEmptyMessage)
        }
    }

    private func inboxFilterShortcut(
        icon: String,
        title: String,
        isHighlighted: Bool,
        badgeCount: Int,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: SplickTheme.Spacing.xxxs) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(
                            isDisabled
                                ? SplickTheme.Colors.textSecondary.opacity(0.55)
                                : isHighlighted
                                    ? SplickTheme.Colors.primaryGradientStart
                                    : SplickTheme.Colors.textSecondary
                        )

                    Text(title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(
                            isDisabled
                                ? SplickTheme.Colors.textSecondary.opacity(0.55)
                                : isHighlighted
                                    ? SplickTheme.Colors.primaryGradientStart
                                    : SplickTheme.Colors.textSecondary
                        )
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.85)
                        .lineSpacing(0)
                        .frame(minWidth: 68)
                }
                .padding(.top, SplickTheme.Spacing.xxs)
                .padding(.bottom, SplickTheme.Spacing.xs)
                .padding(.horizontal, SplickTheme.Spacing.xs)
                .frame(minWidth: 84)
                .background(
                    isHighlighted
                        ? SplickTheme.Colors.primaryGradientStart.opacity(0.1)
                        : SplickTheme.Colors.secondaryBackground
                )
                .clipShape(Capsule(style: .continuous))
                .opacity(isDisabled ? 0.72 : 1)

                if badgeCount > 0 {
                    inboxFilterShortcutBadge(count: badgeCount)
                        .padding(.trailing, 8)
                        .padding(.top, 5)
                }
            }
            .frame(minWidth: 84)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isDisabled
                ? "\(title), \(languageService.text(.messagingFilterComingSoon))"
                : badgeCount > 0 ? "\(title), \(badgeCount)" : title
        )
    }

    private func inboxFilterShortcutBadge(count: Int) -> some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, count > 9 ? 3 : 4)
            .padding(.vertical, 1.5)
            .background {
                Capsule(style: .continuous)
                    .fill(SplickTheme.Colors.error)
            }
    }
}
