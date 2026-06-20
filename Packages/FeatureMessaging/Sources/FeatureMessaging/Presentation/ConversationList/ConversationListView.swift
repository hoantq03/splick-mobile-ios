import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain

public struct ConversationListView: View {
    @ObservedObject private var viewModel: ConversationListViewModel
    @EnvironmentObject private var languageService: LanguageService
    @State private var path = NavigationPath()
    @State private var searchDraft = ""
    @FocusState private var isSearchFocused: Bool

    private var isSearching: Bool {
        !searchDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public init(viewModel: ConversationListViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                conversationListContent

                if isSearching {
                    searchResultsContent
                        .background(SplickTheme.Colors.background)
                        .transition(.opacity)
                }
            }
            .animation(MessagingSearchChromeAnimation.resultsSpring, value: isSearching)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                MessagingConversationChrome(
                    title: languageService.text(.messagingTitle),
                    searchDraft: $searchDraft,
                    searchPlaceholder: languageService.text(.messagingSearchPlaceholder),
                    cancelLabel: languageService.text(.commonCancel),
                    showsSearchSpinner: viewModel.isRefreshingSearch,
                    isSearchFocused: $isSearchFocused,
                    onCancel: dismissSearch
                )
            }
            .refreshable {
                if isSearching {
                    viewModel.onSearchQueryChanged(searchDraft)
                } else {
                    await viewModel.refresh()
                }
            }
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
                icon: "message.slash",
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
        ScrollView {
            LazyVStack(spacing: 0) {
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
        }
        .scrollDismissesKeyboard(.interactively)
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
        ScrollView {
            LazyVStack(spacing: 0) {
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
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
