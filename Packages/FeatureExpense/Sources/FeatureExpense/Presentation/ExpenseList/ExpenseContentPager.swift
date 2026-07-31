import SwiftUI
import DesignSystem

private enum ExpensePagerMotion {
    static let spring = Animation.spring(response: 0.36, dampingFraction: 0.72, blendDuration: 0.04)
}

/// Horizontal paging between expense segments — History / Overview / Friends.
/// Uses an offset HStack so pill taps slide both pages (TabView page-style often snaps).
struct ExpenseContentPager<History: View, Overview: View, Friends: View>: View {
    @Binding var selection: ExpenseContentSegment
    @ViewBuilder var history: () -> History
    @ViewBuilder var overview: () -> Overview
    @ViewBuilder var friends: () -> Friends

    @State private var pagerIndex: Int = 1

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)

            HStack(spacing: 0) {
                page(history, segment: .history, width: width)
                page(overview, segment: .overview, width: width)
                page(friends, segment: .friends, width: width)
            }
            .frame(width: width * CGFloat(expenseSegmentStripOrder.count), alignment: .leading)
            .offset(x: -CGFloat(pagerIndex) * width)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            pagerIndex = expenseSegmentStripOrder.firstIndex(of: selection) ?? 1
        }
        .onChange(of: selection) { newSelection in
            let idx = expenseSegmentStripOrder.firstIndex(of: newSelection) ?? 1
            guard idx != pagerIndex else { return }
            withAnimation(ExpensePagerMotion.spring) {
                pagerIndex = idx
            }
        }
    }

    private func page<Content: View>(
        _ content: () -> Content,
        segment: ExpenseContentSegment,
        width: CGFloat
    ) -> some View {
        content()
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .environment(\.scrollChromeTrackingEnabled, selection == segment)
    }
}
