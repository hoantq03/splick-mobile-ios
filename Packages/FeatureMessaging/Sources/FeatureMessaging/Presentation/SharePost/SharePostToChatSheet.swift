import SwiftUI
import UIKit
import Common
import DesignSystem
import Localization
import SplickDomain
import FeatureStickers

public struct SharePostToChatSheet: View {
    @ObservedObject private var viewModel: SharePostViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss

    private let shareText: String
    @State private var showSystemShare = false
    @State private var copiedPulse = false
    @State private var sendSucceeded = false
    @State private var compactSheetHeight: CGFloat = ShareSheetLayout.defaultHeight
    @State private var sheetDetent: PresentationDetent = .height(ShareSheetLayout.defaultHeight)
    @FocusState private var messageFocused: Bool
    @EnvironmentObject private var emojiStore: CustomEmojiStore
    @Environment(\.customEmojiDependencies) private var customEmojiDependencies
    @Environment(\.currentUserSummary) private var currentUserSummary
    @Environment(\.messagingGifPickerFactory) private var messagingGifPickerFactory
    @State private var gifPickerViewModel: GifPickerViewModel?
    @State private var showAttachmentPicker = false
    @State private var showEmojiInsertPicker = false
    @State private var showCustomEmojiUpload = false
    @State private var gifPreviewRoute: AttachmentPreviewRoute?

    public init(viewModel: SharePostViewModel, shareText: String) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.shareText = shareText
    }

    private var isSearching: Bool {
        !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, SplickTheme.Spacing.md)
                    .padding(.bottom, SplickTheme.Spacing.xs)
            }
            recipientContent
            externalActions
            composerBar
        }
        .fixedSize(horizontal: false, vertical: !isSearching)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: ShareSheetHeightKey.self, value: proxy.size.height)
            }
        }
        .onPreferenceChange(ShareSheetHeightKey.self, perform: updateCompactHeight)
        .ignoresSafeArea(.keyboard)
        .task {
            await viewModel.loadDirectoryIfNeeded()
        }
        .onChange(of: viewModel.searchQuery) { newValue in
            viewModel.onSearchQueryChanged(newValue)
        }
        .onChange(of: isSearching) { searching in
            sheetDetent = searching ? .large : .height(compactSheetHeight)
        }
        .sheet(isPresented: $showSystemShare) {
            SystemActivityShareSheet(items: [shareText, viewModel.shareURL])
        }
        .sheet(isPresented: $showEmojiInsertPicker) {
            EmojiPickerSheet(
                currentUserId: currentUserSummary?.id,
                mode: .inlineInsert,
                onPick: { emoji in viewModel.insertEmoji(emoji) },
                onOpenUpload: { openCustomEmojiUpload() }
            )
        }
        .sheet(isPresented: $showCustomEmojiUpload) {
            if let deps = customEmojiDependencies {
                CustomEmojiUploadSheet(
                    currentUserId: currentUserSummary?.id,
                    customEmojiFetcher: deps.fetcher,
                    uploadMediaUseCase: deps.uploadMediaUseCase,
                    addEmojiUseCase: deps.addEmojiUseCase,
                    deleteEmojiUseCase: deps.deleteEmojiUseCase
                )
            }
        }
        .sheet(isPresented: $showAttachmentPicker) {
            if let gifPickerViewModel {
                AttachmentPickerView(
                    viewModel: gifPickerViewModel,
                    currentUserId: currentUserSummary?.id,
                    onSelectGif: { sticker in
                        showAttachmentPicker = false
                        viewModel.attachGif(stickerId: sticker.id, url: sticker.url)
                    },
                    onSelectEmoji: { emoji in
                        viewModel.insertEmoji(emoji)
                        showAttachmentPicker = false
                    }
                )
                .environmentObject(languageService)
                .environmentObject(emojiStore)
                .environment(\.currentUserSummary, currentUserSummary)
                .environment(\.customEmojiDependencies, customEmojiDependencies)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .splickWindowFullScreenCover(item: $gifPreviewRoute) { route in
            gifFullscreenPreview(at: route.index)
        }
        .presentationDetents(presentedDetents, selection: $sheetDetent)
        .modifier(ShareSheetContentInteraction())
        .presentationDragIndicator(.visible)
    }

    private var presentedDetents: Set<PresentationDetent> {
        if isSearching {
            return [.medium, .large]
        }
        return [.height(compactSheetHeight)]
    }

    private func updateCompactHeight(_ height: CGFloat) {
        guard height > 0, abs(height - compactSheetHeight) > 1 else { return }
        compactSheetHeight = height
        if !isSearching {
            sheetDetent = .height(height)
        }
    }

    private var header: some View {
        ZStack {
            Text(languageService.text(.commonShare))
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
            HStack {
                Button(languageService.text(.commonCancel)) { dismiss() }
                    .font(SplickTheme.Typography.body)
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                Spacer()
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.top, SplickTheme.Spacing.xs)
        .padding(.bottom, SplickTheme.Spacing.sm)
    }

    private var searchBar: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            TextField(languageService.text(.feedShareToChatSearch), text: $viewModel.searchQuery)
                .font(SplickTheme.Typography.callout)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if viewModel.isSearching {
                SplickSpinner(size: .small)
            } else if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                    viewModel.onSearchQueryChanged("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.sm)
        .padding(.vertical, 10)
        .background { ShareGlassRoundedRect(cornerRadius: 22) }
        .clipShape(Capsule(style: .continuous))
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.bottom, SplickTheme.Spacing.sm)
    }

    @ViewBuilder
    private var recipientContent: some View {
        if viewModel.isLoading {
            SplickSpinner()
                .frame(maxWidth: .infinity)
                .padding(.vertical, SplickTheme.Spacing.lg)
        } else if isSearching {
            searchResults
        } else if viewModel.visibleRecipients.isEmpty && viewModel.visibleRemoteUsers.isEmpty {
            Text(languageService.text(.feedShareToChatSelectHint))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SplickTheme.Spacing.md)
                .padding(.bottom, SplickTheme.Spacing.sm)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: SplickTheme.Spacing.md) {
                    ForEach(viewModel.visibleRecipients) { recipient in
                        recipientTile(
                            title: recipient.title,
                            avatarURL: recipient.avatarURL,
                            userId: recipient.userIdForAvatar,
                            selected: viewModel.isSelected(recipient)
                        ) {
                            viewModel.toggle(recipient)
                        }
                    }
                    ForEach(viewModel.visibleRemoteUsers) { user in
                        recipientTile(
                            title: user.preferredName,
                            avatarURL: user.avatarURL,
                            userId: user.id,
                            selected: viewModel.isRemoteUserSelected(user)
                        ) {
                            viewModel.toggleRemoteUser(user)
                        }
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
                .padding(.bottom, SplickTheme.Spacing.sm)
            }
        }
    }

    private func recipientTile(
        title: String,
        avatarURL: URL?,
        userId: UUID?,
        selected: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                AvatarView(imageURL: avatarURL, name: title, size: .medium, userId: userId)
                    .overlay {
                        Circle()
                            .stroke(
                                selected ? SplickTheme.Colors.primaryGradientStart : Color.clear,
                                lineWidth: 2.5
                            )
                            .padding(-3)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(
                                    .white,
                                    sendSucceeded
                                        ? SplickTheme.Colors.success
                                        : SplickTheme.Colors.primaryGradientStart
                                )
                                .font(.system(size: 18))
                        }
                    }
                    .scaleEffect(selected ? 1.04 : 1)
                Text(sendSucceeded && selected ? languageService.text(.feedShareToChatSent) : title)
                    .font(SplickTheme.Typography.caption)
                    .fontWeight(selected ? .semibold : .regular)
                    .foregroundStyle(
                        sendSucceeded && selected
                            ? SplickTheme.Colors.success
                            : SplickTheme.Colors.textPrimary
                    )
                    .lineLimit(1)
                    .frame(width: 68)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: selected)
        .animation(.easeInOut(duration: 0.2), value: sendSucceeded)
    }

    private var searchResults: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.visibleRecipients) { recipient in
                    searchRow(
                        title: recipient.title,
                        subtitle: recipient.subtitle,
                        avatarURL: recipient.avatarURL,
                        userId: recipient.userIdForAvatar,
                        selected: viewModel.isSelected(recipient)
                    ) {
                        viewModel.toggle(recipient)
                    }
                }
                ForEach(viewModel.visibleRemoteUsers) { user in
                    searchRow(
                        title: user.preferredName,
                        subtitle: "@\(user.username)",
                        avatarURL: user.avatarURL,
                        userId: user.id,
                        selected: viewModel.isRemoteUserSelected(user)
                    ) {
                        viewModel.toggleRemoteUser(user)
                    }
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
        }
        .frame(maxHeight: .infinity)
    }

    private func searchRow(
        title: String,
        subtitle: String?,
        avatarURL: URL?,
        userId: UUID?,
        selected: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: SplickTheme.Spacing.sm) {
                AvatarView(imageURL: avatarURL, name: title, size: .compact, userId: userId)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SplickTheme.Typography.headline)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        selected
                            ? SplickTheme.Colors.primaryGradientStart
                            : SplickTheme.Colors.textTertiary
                    )
            }
            .padding(.vertical, SplickTheme.Spacing.sm)
        }
        .buttonStyle(.plain)
    }

    private var externalActions: some View {
        HStack(spacing: SplickTheme.Spacing.lg) {
            shareActionButton(
                title: languageService.text(.feedShareToChatCopyLink),
                systemImage: copiedPulse ? "checkmark" : "link"
            ) {
                UIPasteboard.general.string = viewModel.shareURL.absoluteString
                viewModel.copyLinkSucceeded()
                copiedPulse = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                Task {
                    try? await Task.sleep(for: .milliseconds(1_400))
                    copiedPulse = false
                }
            }

            shareActionButton(
                title: languageService.text(.feedShareToChatMore),
                systemImage: "square.and.arrow.up"
            ) {
                showSystemShare = true
            }
            Spacer()
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.top, SplickTheme.Spacing.md)
        .padding(.bottom, SplickTheme.Spacing.sm)
    }

    private func shareActionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background { ShareGlassCircle() }
                Text(title)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private var composerBar: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            if !viewModel.gifSubmissions.isEmpty {
                PendingAttachmentStrip(
                    attachments: viewModel.gifSubmissions,
                    thumbnailWidth: 64,
                    thumbnailHeight: 64,
                    onTapAttachment: { index in
                        gifPreviewRoute = AttachmentPreviewRoute(index: index)
                    },
                    onRemoveAttachment: { index in
                        viewModel.removeGif(at: index)
                    }
                )
            }

            HStack(alignment: .bottom, spacing: 10) {
                emojiMenuButton

                TextField(
                    languageService.text(.feedShareToChatMessagePlaceholder),
                    text: $viewModel.messageNote,
                    axis: .vertical
                )
                .font(SplickTheme.Typography.body)
                .lineLimit(1...4)
                .padding(.horizontal, SplickTheme.Spacing.sm)
                .padding(.vertical, 8)
                .background { ShareGlassRoundedRect(cornerRadius: 20) }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .focused($messageFocused)

            Button {
                Task { await sendIfPossible() }
            } label: {
                ZStack {
                    if viewModel.isSending {
                        SplickSpinner(size: .small, usesBrandColors: false)
                    } else if sendSucceeded {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(SplickTheme.Colors.success)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 34))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    }
                }
                .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSend && !sendSucceeded)
            .opacity(viewModel.canSend || viewModel.isSending || sendSucceeded ? 1 : 0.28)
            .scaleEffect(viewModel.canSend || sendSucceeded ? 1 : 0.86)
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: viewModel.canSend)
            .accessibilityLabel(languageService.text(.feedShareToChatSend))
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.bottom, SplickTheme.Spacing.md)
    }

    @ViewBuilder
    private var emojiMenuButton: some View {
        Button {
            presentAttachmentPicker()
        } label: {
            Image(systemName: "face.smiling")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .frame(width: 36, height: 36)
                .background { ShareGlassCircle() }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(languageService.text(.stickersEmoji))
    }

    private func presentAttachmentPicker() {
        messageFocused = false
        if gifPickerViewModel == nil {
            gifPickerViewModel = messagingGifPickerFactory?()
            guard gifPickerViewModel != nil else {
                showEmojiInsertPicker = true
                return
            }
            DispatchQueue.main.async {
                showAttachmentPicker = true
            }
            return
        }
        showAttachmentPicker = true
    }

    private func openCustomEmojiUpload() {
        showEmojiInsertPicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            showCustomEmojiUpload = true
        }
    }

    @ViewBuilder
    private func gifFullscreenPreview(at index: Int) -> some View {
        if viewModel.gifSubmissions.indices.contains(index),
           let url = viewModel.gifSubmissions[index].remoteURL {
            RemoteGifFullscreenPreview(url: url) {
                gifPreviewRoute = nil
            }
        }
    }

    private func sendIfPossible() async {
        guard await viewModel.send() else { return }
        sendSucceeded = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        try? await Task.sleep(for: .milliseconds(700))
        dismiss()
    }
}

private struct ShareGlassRoundedRect: View {
    var cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular)
        } else {
            shape
                .fill(.ultraThinMaterial)
        }
    }
}

private struct ShareGlassCircle: View {
    var body: some View {
        if #available(iOS 26.0, *) {
            Circle()
                .fill(.clear)
                .glassEffect(.regular)
        } else {
            Circle()
                .fill(.ultraThinMaterial)
        }
    }
}

struct SystemActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private enum ShareSheetLayout {
    static let defaultHeight: CGFloat = 420
}

private struct ShareSheetContentInteraction: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.presentationContentInteraction(.scrolls)
        } else {
            content
        }
    }
}

private struct ShareSheetHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
