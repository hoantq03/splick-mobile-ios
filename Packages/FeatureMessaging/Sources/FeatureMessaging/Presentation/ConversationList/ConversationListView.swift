import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain

private enum MessagingSearchChromeMetrics {
    static let rowHeight: CGFloat = 44
    static let verticalPadding: CGFloat = SplickTheme.Spacing.sm
    static var insetHeight: CGFloat { rowHeight + verticalPadding * 2 }
}

public struct ConversationListView: View {
    @ObservedObject private var viewModel: ConversationListViewModel
    @EnvironmentObject private var languageService: LanguageService
    @State private var path = NavigationPath()
    @State private var searchDraft = ""
    @FocusState private var isSearchFocused: Bool
    @Namespace private var searchNamespace

    public init(viewModel: ConversationListViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                conversationListContent
                    .opacity(showSearchLayer ? 0 : 1)
                    .allowsHitTesting(!showSearchLayer)

                if showSearchLayer {
                    searchResultsContent
                }
            }
            .navigationTitle(languageService.text(.messagingTitle))
            .splickProfileToolbar(isSuppressed: isSearchFocused)
            .safeAreaInset(edge: .top, spacing: 0) {
                Group {
                    if isSearchFocused {
                        focusedSearchHeader
                    } else {
                        collapsedSearchHeader
                    }
                }
                .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isSearchFocused)
            }
            .refreshable {
                if viewModel.isSearching {
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
        .onChange(of: viewModel.searchQuery) { newValue in
            guard newValue != searchDraft else { return }
            searchDraft = newValue
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
            searchDraft = viewModel.searchQuery
            guard viewModel.conversations.isEmpty else { return }
            Task { await viewModel.load() }
        }
    }

    private var showSearchLayer: Bool {
        isSearchFocused || viewModel.isSearching
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

    private var collapsedSearchHeader: some View {
        messagingSearchCapsule(showTrailingSpinner: viewModel.isRefreshingSearch)
            .matchedGeometryEffect(id: "messagingSearchCapsule", in: searchNamespace)
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, MessagingSearchChromeMetrics.verticalPadding)
            .frame(maxWidth: .infinity)
            .background(SplickTheme.Colors.background)
    }

    private var focusedSearchHeader: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            messagingSearchCapsule(showTrailingSpinner: viewModel.isRefreshingSearch)
                .matchedGeometryEffect(id: "messagingSearchCapsule", in: searchNamespace)

            Button {
                dismissSearch()
            } label: {
                Text(languageService.text(.commonCancel))
                    .font(SplickTheme.Typography.callout.weight(.medium))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
            }
            .buttonStyle(.plain)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, MessagingSearchChromeMetrics.verticalPadding)
        .frame(maxWidth: .infinity)
        .background {
            SplickTheme.Colors.background
                .ignoresSafeArea(edges: .top)
        }
    }

    private func messagingSearchCapsule(showTrailingSpinner: Bool) -> some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            TextField(
                languageService.text(.messagingSearchPlaceholder),
                text: $searchDraft
            )
            .font(SplickTheme.Typography.callout)
            .focused($isSearchFocused)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .submitLabel(.search)

            if showTrailingSpinner {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: MessagingSearchChromeMetrics.rowHeight)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(Capsule(style: .continuous))
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
        case .idle, .loading where viewModel.searchResults.isEmpty:
            LoadingView(message: languageService.text(.messagingSearchLoading))

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

        case .loading, .loaded:
            searchResultsList(viewModel.searchResults)
        }
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
                            query: searchDraft,
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
    }

    private func dismissSearch() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
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

        isSearchFocused = false
        viewModel.searchQuery = ""
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
    }
}
