import SwiftUI
import DesignSystem
import Localization
import SplickDomain

struct MentionPickerPopup: View {
    @EnvironmentObject private var languageService: LanguageService
    @ObservedObject var viewModel: MentionFriendsViewModel
    let onSelect: (UserSummary) -> Void

    private let rowHeight: CGFloat = 48
    private let maxVisibleRows: CGFloat = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(languageService.text(.feedMentionSuggestions))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.friends.isEmpty, !viewModel.isLoading {
                        Text(languageService.text(.feedCreateFriendsNotFound))
                            .font(.system(size: 12))
                            .foregroundStyle(SplickTheme.Colors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                    }

                    ForEach(viewModel.friends) { friend in
                        Button {
                            onSelect(friend)
                        } label: {
                            HStack(spacing: 10) {
                                AvatarView(
                                    imageURL: friend.avatarURL,
                                    name: friend.displayName,
                                    size: .small
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.displayName)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                                    Text("@\(friend.username)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .frame(height: rowHeight)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            Task { await viewModel.loadMoreIfNeeded(currentFriend: friend) }
                        }

                        Divider()
                            .padding(.leading, 52)
                    }

                    if viewModel.isLoading {
                        SplickSpinner(size: .small)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
            }
            .frame(maxHeight: rowHeight * maxVisibleRows)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SplickTheme.Colors.secondaryBackground)
                .shadow(color: .black.opacity(0.12), radius: 8, y: -2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(SplickTheme.Colors.divider, lineWidth: 0.5)
        )
    }
}
