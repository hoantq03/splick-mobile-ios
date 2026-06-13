import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain
import Storage

public struct ChatThreadView: View {
    @ObservedObject private var viewModel: ChatThreadViewModel
    @EnvironmentObject private var languageService: LanguageService
    @State private var inputText: String = ""
    @State private var scrollProxy: ScrollViewProxy? = nil

    private let currentUserId: UUID
    private let navigationTitle: String

    public init(viewModel: ChatThreadViewModel, currentUserId: UUID, navigationTitle: String = "") {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.currentUserId = currentUserId
        self.navigationTitle = navigationTitle
    }

    public var body: some View {
        VStack(spacing: 0) {
            messageArea
            Divider()
            inputBar
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onFirstAppear {
            Task { await viewModel.load() }
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
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: SplickTheme.Spacing.xs) {
                        ForEach(messages) { message in
                            MessageBubble(
                                message: message,
                                isOutgoing: message.senderId == currentUserId
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal, SplickTheme.Spacing.md)
                    .padding(.vertical, SplickTheme.Spacing.sm)
                }
                .onAppear {
                    scrollProxy = proxy
                    scrollToBottom(proxy: proxy, messages: messages, animated: false)
                }
                .onChange(of: messages.count) { _ in
                    scrollToBottom(proxy: proxy, messages: messages, animated: true)
                }
            }
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

    private func scrollToBottom(proxy: ScrollViewProxy, messages: [ChatMessage], animated: Bool) {
        guard let last = messages.last else { return }
        if animated {
            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
        } else {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
}
