import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain

public struct ConversationListView: View {
    @ObservedObject private var viewModel: ConversationListViewModel
    @EnvironmentObject private var languageService: LanguageService
    @State private var path = NavigationPath()

    public init(viewModel: ConversationListViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                messagingSearchField

                Group {
                    if viewModel.isSearching {
                        searchResultsContent
                    } else {
                        conversationListContent
                    }
                }
            }
            .navigationTitle(languageService.text(.messagingTitle))
            .splickProfileToolbar()
            .refreshable {
                if viewModel.isSearching {
                    viewModel.onSearchQueryChanged(viewModel.searchQuery)
                } else {
                    await viewModel.refresh()
                }
            }
            .navigationDestination(for: Conversation.self) { conversation in
                ChatThreadNavigationWrapper(conversation: conversation)
            }
        }
        .onChange(of: viewModel.searchQuery) { newValue in
            viewModel.onSearchQueryChanged(newValue)
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

    private var messagingSearchField: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            TextField(
                languageService.text(.messagingSearchPlaceholder),
                text: $viewModel.searchQuery
            )
            .font(SplickTheme.Typography.callout)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(Capsule(style: .continuous))
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
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
        case .idle, .loading:
            LoadingView(message: languageService.text(.messagingSearchLoading))

        case .failed(let message):
            ErrorView(message: message) {
                viewModel.onSearchQueryChanged(viewModel.searchQuery)
            }

        case .loaded(let results) where results.isEmpty:
            EmptyStateView(
                icon: "magnifyingglass",
                title: languageService.text(.messagingSearchEmptyTitle),
                message: languageService.text(.messagingSearchEmptyMessage)
            )

        case .loaded(let results):
            List(results) { friend in
                Button {
                    Task { await openConversation(with: friend) }
                } label: {
                    FriendSearchRowView(
                        friend: friend,
                        isStarting: viewModel.isStartingConversation
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isStartingConversation)
            }
            .listStyle(.plain)
        }
    }

    private func openConversation(with friend: UserSummary) async {
        guard let conversation = await viewModel.startConversation(with: friend) else { return }
        viewModel.searchQuery = ""
        viewModel.onSearchQueryChanged("")
        path.append(conversation)
        await viewModel.refresh()
    }

    @ViewBuilder
    private func conversationList(_ items: [Conversation]) -> some View {
        List(items) { conversation in
            Button {
                path.append(conversation)
            } label: {
                ConversationRowView(conversation: conversation)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
    }
}

private struct FriendSearchRowView: View {
    let friend: UserSummary
    let isStarting: Bool

    var body: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            AvatarView(
                imageURL: friend.avatarURL,
                name: friend.displayName,
                size: .medium
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                Text("@\(friend.username)")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }

            Spacer()

            if isStarting {
                ProgressView().controlSize(.small)
            }
        }
    }
}
