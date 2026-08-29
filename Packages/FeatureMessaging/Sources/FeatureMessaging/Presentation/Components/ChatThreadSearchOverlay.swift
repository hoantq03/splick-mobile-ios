import SwiftUI
import Common
import DesignSystem
import Localization

struct ChatThreadSearchOverlay: View {
    @ObservedObject var viewModel: ChatThreadViewModel
    @Binding var query: String
    @FocusState.Binding var isSearchFocused: Bool
    let onSelectHit: (MessageSearchHit) -> Void
    let onClose: () -> Void

    @EnvironmentObject private var languageService: LanguageService

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            results
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(SplickTheme.Colors.background)
        .contentShape(Rectangle())
    }

    private var searchBar: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            HStack(spacing: SplickTheme.Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)

                TextField(
                    languageService.text(.messagingChatSearchPlaceholder),
                    text: $query
                )
                .font(SplickTheme.Typography.callout)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isSearchFocused)

                if case .loading = viewModel.threadSearchState, viewModel.threadSearchHits.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, SplickTheme.Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(SplickTheme.Colors.secondaryBackground)
            .clipShape(Capsule(style: .continuous))

            Button(languageService.text(.commonCancel), action: onClose)
                .font(SplickTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
    }

    @ViewBuilder
    private var results: some View {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        switch viewModel.threadSearchState {
        case .loading where viewModel.threadSearchHits.isEmpty:
            placeholder(
                message: languageService.text(.messagingSearchLoading),
                showsSpinner: true
            )

        case .failed(let message):
            ErrorView(message: message) {
                viewModel.onThreadSearchQueryChanged(query)
            }

        case .loaded(let hits) where hits.isEmpty:
            EmptyStateView(
                icon: "magnifyingglass",
                title: languageService.text(.messagingSearchEmptyTitle),
                message: languageService.text(.messagingSearchEmptyMessage)
            )

        case .idle where trimmed.count == 1:
            placeholder(
                message: languageService.text(.messagingChatSearchHint),
                showsSpinner: false
            )

        case .idle where trimmed.isEmpty:
            placeholder(
                message: languageService.text(.messagingChatSearchPlaceholder),
                showsSpinner: false
            )

        default:
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.threadSearchHits) { hit in
                        Button {
                            onSelectHit(hit)
                        } label: {
                            MessagingSearchResultRowView(
                                result: .message(hit),
                                query: viewModel.activeThreadSearchQuery,
                                isStarting: false
                            )
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

    private func placeholder(message: String, showsSpinner: Bool) -> some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            if showsSpinner {
                ProgressView()
            }
            Text(message)
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SplickTheme.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
