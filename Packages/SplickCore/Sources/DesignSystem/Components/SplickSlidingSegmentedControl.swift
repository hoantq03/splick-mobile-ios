import SwiftUI

/// Pill segmented control with a sliding selection indicator — matches Android
/// `SlidingMethodTabs` used in change-password / account-security flows.
public struct SplickSlidingSegmentedControl<Selection: Hashable>: View {
    private let titles: [String]
    private let values: [Selection]
    @Binding private var selection: Selection

    public init(
        titles: [String],
        values: [Selection],
        selection: Binding<Selection>
    ) {
        precondition(titles.count == values.count && !titles.isEmpty)
        self.titles = titles
        self.values = values
        _selection = selection
    }

    public var body: some View {
        let selectedIndex = values.firstIndex(of: selection) ?? 0
        GeometryReader { geo in
            let tabWidth = geo.size.width / CGFloat(titles.count)
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(SplickTheme.Colors.cardBackground)
                    .shadow(
                        color: Color.black.opacity(0.06),
                        radius: 4,
                        y: 2
                    )
                    .frame(width: max(tabWidth - 2, 0), height: geo.size.height - 6)
                    .offset(x: tabWidth * CGFloat(selectedIndex) + 1)
                    .animation(.spring(response: 0.32, dampingFraction: 0.86), value: selection)

                HStack(spacing: 0) {
                    ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                selection = values[index]
                            }
                        } label: {
                            Text(title)
                                .font(SplickTheme.Typography.callout.weight(
                                    index == selectedIndex ? .semibold : .medium
                                ))
                                .foregroundStyle(
                                    index == selectedIndex
                                        ? SplickTheme.Colors.textPrimary
                                        : SplickTheme.Colors.textSecondary
                                )
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(3)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                Capsule(style: .continuous)
                    .fill(SplickTheme.Colors.secondaryBackground)
                    .shadow(
                        color: SplickTheme.Shadow.card.color,
                        radius: SplickTheme.Shadow.card.radius,
                        x: SplickTheme.Shadow.card.x,
                        y: SplickTheme.Shadow.card.y
                    )
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
            }
        }
        .frame(height: 44)
        .accessibilityElement(children: .contain)
    }
}
