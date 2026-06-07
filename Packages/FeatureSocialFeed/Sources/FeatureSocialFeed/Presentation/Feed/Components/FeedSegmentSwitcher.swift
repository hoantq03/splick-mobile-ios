import SwiftUI
import DesignSystem
import Localization

struct FeedSegmentSwitcher: View {
    @Binding var selection: FeedContentSegment
    let isExpanded: Bool
    let feedLabel: String
    let albumLabel: String

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                ModernFeedSegmentSwitcher(
                    selection: $selection,
                    isExpanded: isExpanded,
                    feedLabel: feedLabel,
                    albumLabel: albumLabel
                )
            } else {
                LegacyFeedSegmentSwitcher(
                    selection: $selection,
                    isExpanded: isExpanded,
                    feedLabel: feedLabel,
                    albumLabel: albumLabel
                )
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isExpanded)
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: selection)
    }
}

// MARK: - Legacy (iOS 16–25)

private struct LegacyFeedSegmentSwitcher: View {
    @Binding var selection: FeedContentSegment
    let isExpanded: Bool
    let feedLabel: String
    let albumLabel: String

    private let segmentHeight: CGFloat = 36

    var body: some View {
        Group {
            if isExpanded {
                HStack(spacing: 4) {
                    segmentButton(.feed, label: feedLabel)
                    segmentButton(.album, label: albumLabel)
                }
                .padding(4)
                .background(
                    Capsule(style: .continuous)
                        .fill(SplickTheme.Colors.secondaryBackground)
                )
            } else {
                Text(selection == .feed ? feedLabel : albumLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: segmentHeight)
            }
        }
        .frame(height: segmentHeight)
    }

    private func segmentButton(_ segment: FeedContentSegment, label: String) -> some View {
        let isSelected = selection == segment
        return Button {
            selection = segment
        } label: {
            Text(label)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(
                    isSelected
                        ? SplickTheme.Colors.textPrimary
                        : SplickTheme.Colors.textSecondary
                )
                .frame(maxWidth: .infinity)
                .frame(height: segmentHeight - 8)
                .background {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(SplickTheme.Colors.tertiaryBackground)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Liquid glass (iOS 26+)

@available(iOS 26.0, *)
private struct ModernFeedSegmentSwitcher: View {
    @Binding var selection: FeedContentSegment
    let isExpanded: Bool
    let feedLabel: String
    let albumLabel: String

    private let segmentHeight: CGFloat = 36
    private let cornerRadius: CGFloat = 18

    var body: some View {
        Group {
            if isExpanded {
                HStack(spacing: 4) {
                    glassSegmentButton(.feed, label: feedLabel)
                    glassSegmentButton(.album, label: albumLabel)
                }
                .padding(4)
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.clear)
                        .glassEffect(.regular)
                }
            } else {
                Text(selection == .feed ? feedLabel : albumLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: segmentHeight)
                    .padding(.horizontal, 4)
            }
        }
        .frame(height: segmentHeight)
    }

    private func glassSegmentButton(_ segment: FeedContentSegment, label: String) -> some View {
        let isSelected = selection == segment
        return Button {
            selection = segment
        } label: {
            Text(label)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(
                    isSelected
                        ? SplickTheme.Colors.textPrimary
                        : SplickTheme.Colors.textSecondary
                )
                .frame(maxWidth: .infinity)
                .frame(height: segmentHeight - 8)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: cornerRadius - 4, style: .continuous)
                            .fill(.clear)
                            .glassEffect(.regular)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
