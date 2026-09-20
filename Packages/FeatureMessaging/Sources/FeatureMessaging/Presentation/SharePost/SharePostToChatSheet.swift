import SwiftUI
import UIKit
import Common
import DesignSystem
import Localization
import SplickDomain

public struct SharePostToChatSheet: View {
    @ObservedObject private var viewModel: SharePostViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss

    private let shareText: String
    @State private var showSystemShare = false
    @State private var copiedPulse = false
    @State private var sendSucceeded = false
    @State private var sheetDetent: PresentationDetent = .medium
    @FocusState private var messageFocused: Bool

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
            Spacer(minLength: SplickTheme.Spacing.sm)
            if !messageFocused {
                externalActions
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composerBar
        }
        .task {
            await viewModel.loadDirectoryIfNeeded()
        }
        .onChange(of: viewModel.searchQuery) { newValue in
            viewModel.onSearchQueryChanged(newValue)
        }
        .onChange(of: messageFocused) { focused in
            if focused {
                sheetDetent = .large
            }
        }
        .sheet(isPresented: $showSystemShare) {
            SystemActivityShareSheet(items: [shareText, viewModel.shareURL])
        }
        .presentationDetents([.medium, .large], selection: $sheetDetent)
        .presentationDragIndicator(.visible)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isSearching {
            searchResults
        } else if viewModel.visibleRecipients.isEmpty && viewModel.visibleRemoteUsers.isEmpty {
            Text(languageService.text(.feedShareToChatSelectHint))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, SplickTheme.Spacing.md)
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
            .frame(maxHeight: .infinity, alignment: .top)
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
        HStack(alignment: .bottom, spacing: 10) {
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
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.bottom, SplickTheme.Spacing.md)
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
