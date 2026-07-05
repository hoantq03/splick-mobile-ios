import SwiftUI
import Combine
import Common
import DesignSystem
import Localization
import SplickDomain

public struct ConversationListView: View {
    @ObservedObject private var viewModel: ConversationListViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @Environment(\.pullToRefreshActive) private var pullToRefreshActive
    @State private var isPullRefreshing = false

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

    private var sameTabTapPublisher: AnyPublisher<Void, Never> {
        tabBarScrollState?.sameTabTapSubject.eraseToAnyPublisher()
            ?? Empty().eraseToAnyPublisher()
    }

    private var isSearching: Bool {
        !searchDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public init(viewModel: ConversationListViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                messagingSearchBar

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
            .navigationDestination(for: ChatThreadRoute.self) { route in
                ChatThreadNavigationWrapper(
                    conversation: route.conversation,
                    highlightMessageId: route.highlightMessageId
                )
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
        .onFirstAppear {
            guard viewModel.conversations.isEmpty else { return }
            Task { await viewModel.load() }
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

        case .loaded(let items) where items.isEmpty:
            EmptyStateView(
                icon: "bubble.left.and.bubble.right",
                title: languageService.text(.messagingEmptyTitle),
                message: languageService.text(.messagingEmptyMessage)
            )

        case .loaded(let items):
            conversationList(items)

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
}
