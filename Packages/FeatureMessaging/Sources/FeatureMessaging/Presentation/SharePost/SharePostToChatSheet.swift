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

    public init(viewModel: SharePostViewModel, shareText: String) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.shareText = shareText
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                recipientStrip
                if !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    searchResults
                }
                Divider()
                messageField
                sendBar
                Divider()
                externalShareRow
            }
            .background(SplickTheme.Colors.background)
            .navigationTitle(languageService.text(.commonShare))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) { dismiss() }
                }
            }
            .task {
                await viewModel.loadDirectoryIfNeeded()
            }
            .onChange(of: viewModel.searchQuery) { newValue in
                viewModel.onSearchQueryChanged(newValue)
            }
            .alert(
                languageService.text(.commonError),
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button(languageService.text(.commonOK), role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showSystemShare) {
                SystemActivityShareSheet(items: [shareText, viewModel.shareURL])
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var searchBar: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            TextField(languageService.text(.feedShareToChatSearch), text: $viewModel.searchQuery)
                .font(SplickTheme.Typography.callout)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if viewModel.isSearching {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(Capsule(style: .continuous))
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
    }

    @ViewBuilder
    private var recipientStrip: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, SplickTheme.Spacing.md)
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
            VStack(spacing: 6) {
                AvatarView(imageURL: avatarURL, name: title, size: .medium, userId: userId)
                    .overlay(alignment: .bottomTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, SplickTheme.Colors.primaryGradientStart)
                                .background(Circle().fill(SplickTheme.Colors.background).padding(1))
                        }
                    }
                Text(title)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .frame(width: 64)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var searchResults: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
                ForEach(viewModel.visibleRecipients) { recipient in
                    Button {
                        viewModel.toggle(recipient)
                    } label: {
                        HStack(spacing: SplickTheme.Spacing.sm) {
                            AvatarView(
                                imageURL: recipient.avatarURL,
                                name: recipient.title,
                                size: .compact,
                                userId: recipient.userIdForAvatar
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(recipient.title)
                                    .font(SplickTheme.Typography.headline)
                                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                                if let subtitle = recipient.subtitle {
                                    Text(subtitle)
                                        .font(SplickTheme.Typography.caption)
                                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: viewModel.isSelected(recipient) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(
                                    viewModel.isSelected(recipient)
                                        ? SplickTheme.Colors.primaryGradientStart
                                        : SplickTheme.Colors.textTertiary
                                )
                        }
                        .padding(.vertical, SplickTheme.Spacing.xs)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
        }
        .frame(maxHeight: 180)
    }

    private var messageField: some View {
        TextField(
            languageService.text(.feedShareToChatMessagePlaceholder),
            text: $viewModel.messageNote,
            axis: .vertical
        )
        .font(SplickTheme.Typography.callout)
        .lineLimit(1...4)
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
    }

    private var sendBar: some View {
        HStack {
            if let status = viewModel.statusMessage {
                Text(status)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.success)
            }
            Spacer()
            Button {
                Task {
                    if await viewModel.send() {
                        try? await Task.sleep(for: .milliseconds(450))
                        dismiss()
                    }
                }
            } label: {
                if viewModel.isSending {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(languageService.text(.feedShareToChatSend))
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSend)
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.bottom, SplickTheme.Spacing.sm)
    }

    private var externalShareRow: some View {
        HStack(spacing: SplickTheme.Spacing.lg) {
            Button {
                UIPasteboard.general.string = viewModel.shareURL.absoluteString
                viewModel.copyLinkSucceeded()
                copiedPulse = true
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: copiedPulse ? "checkmark.circle.fill" : "link")
                        .font(.system(size: 20, weight: .semibold))
                    Text(languageService.text(.feedShareToChatCopyLink))
                        .font(SplickTheme.Typography.caption)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Button {
                showSystemShare = true
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20, weight: .semibold))
                    Text(languageService.text(.feedShareToChatMore))
                        .font(SplickTheme.Typography.caption)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(SplickTheme.Colors.textPrimary)
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.md)
    }
}

struct SystemActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
