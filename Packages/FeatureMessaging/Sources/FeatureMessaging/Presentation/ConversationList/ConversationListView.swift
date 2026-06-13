import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain

public struct ConversationListView: View {
    @ObservedObject private var viewModel: ConversationListViewModel
    @EnvironmentObject private var languageService: LanguageService
    @State private var path = NavigationPath()
    @State private var showNewConversation = false
    @State private var newConversationViewModel: NewConversationViewModel?

    private let newConversationViewModelFactory: ((@escaping (Conversation) -> Void) -> NewConversationViewModel)?

    public init(
        viewModel: ConversationListViewModel,
        newConversationViewModelFactory: ((@escaping (Conversation) -> Void) -> NewConversationViewModel)? = nil
    ) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.newConversationViewModelFactory = newConversationViewModelFactory
    }
    public var body: some View {
        NavigationStack(path: $path) {
            Group {
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
            .navigationTitle(languageService.text(.messagingTitle))
            .splickProfileToolbar()
            .toolbar {
                if newConversationViewModelFactory != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            openNewConversationSheet()
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
            }
            .refreshable { await viewModel.refresh() }
            .navigationDestination(for: Conversation.self) { conversation in
                ChatThreadNavigationWrapper(conversation: conversation)
            }
        }
        .sheet(isPresented: $showNewConversation, onDismiss: {
            newConversationViewModel = nil
        }) {
            if let vm = newConversationViewModel {
                NewConversationView(viewModel: vm)
            }
        }
        .onFirstAppear {
            guard viewModel.conversations.isEmpty else { return }
            Task { await viewModel.load() }
        }
    }

    private func openNewConversationSheet() {
        guard let factory = newConversationViewModelFactory else { return }
        newConversationViewModel = factory { conversation in
            showNewConversation = false
            path.append(conversation)
            Task { await viewModel.refresh() }
        }
        showNewConversation = true
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
