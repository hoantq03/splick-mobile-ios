import SwiftUI
import DesignSystem

/// Horizontal paging between expense segments — feed-like swipe between History / Overview / Friends.
struct ExpenseContentPager<History: View, Overview: View, Friends: View>: View {
    @Binding var selection: ExpenseContentSegment
    @ViewBuilder var history: () -> History
    @ViewBuilder var overview: () -> Overview
    @ViewBuilder var friends: () -> Friends

    var body: some View {
        TabView(selection: $selection) {
            history()
                .tag(ExpenseContentSegment.history)
                .environment(\.scrollChromeTrackingEnabled, selection == .history)

            overview()
                .tag(ExpenseContentSegment.overview)
                .environment(\.scrollChromeTrackingEnabled, selection == .overview)

            friends()
                .tag(ExpenseContentSegment.friends)
                .environment(\.scrollChromeTrackingEnabled, selection == .friends)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
