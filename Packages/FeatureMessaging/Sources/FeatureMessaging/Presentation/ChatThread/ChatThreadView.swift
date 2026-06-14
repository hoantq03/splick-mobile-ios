import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain
import Storage

public struct ChatThreadView: View {
    @ObservedObject private var viewModel: ChatThreadViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @State private var inputText: String = ""

    private let currentUserId: UUID
    private let peer: ConversationPeer?
    private let navigationTitle: String

    public init(
        viewModel: ChatThreadViewModel,
        currentUserId: UUID,
        peer: ConversationPeer? = nil,
        navigationTitle: String = ""
    ) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.currentUserId = currentUserId
        self.peer = peer
        self.navigationTitle = navigationTitle
    }

    public var body: some View {
        VStack(spacing: 0) {
            messageArea
            Divider()
            inputBar
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: SplickTheme.Spacing.xs) {
                    AvatarView(
                        imageURL: peer?.avatarUrl.flatMap(URL.init(string:)),
                        name: navigationTitle,
                        size: .small
                    )
                    Text(navigationTitle)
                        .font(SplickTheme.Typography.headline)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                        .lineLimit(1)
                }
            }
        }
        .onAppear { tabBarScrollState?.hide(flushToBottom: true) }
        .onDisappear { tabBarScrollState?.show() }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    @ViewBuilder
    private var messageArea: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView(message: languageService.text(.messagingChatLoading))
        case .loaded(let messages) where messages.isEmpty:
            EmptyStateView(
                icon: "bubble.left",
                title: languageService.text(.messagingChatEmptyTitle),
                message: languageService.text(.messagingChatEmptyMessage)
            )
        case .loaded(let messages):
            ChatMessageListView(
                viewModel: viewModel,
                messages: messages,
                currentUserId: currentUserId
            )
        case .failed(let error):
            ErrorView(message: error) {
                Task { await viewModel.load() }
            }
        }
    }

    @ViewBuilder
    private var inputBar: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            TextField(languageService.text(.messagingInputPlaceholder), text: $inputText, axis: .vertical)
                .lineLimit(1...5)
                .font(SplickTheme.Typography.body)
                .padding(.horizontal, SplickTheme.Spacing.sm)
                .padding(.vertical, SplickTheme.Spacing.xs)
                .background(SplickTheme.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Button {
                let text = inputText
                inputText = ""
                Task { await viewModel.send(body: text) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty
                        ? SplickTheme.Colors.textTertiary
                        : SplickTheme.Colors.primaryGradientStart)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSending)
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
        .background(SplickTheme.Colors.background)
    }
}
