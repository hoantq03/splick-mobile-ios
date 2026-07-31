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
    @State private var dragOffset: CGFloat = 0
    @State private var dragAxis: Axis?

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)

            HStack(spacing: 0) {
                page(history, segment: .history, width: width)
                page(overview, segment: .overview, width: width)
                page(friends, segment: .friends, width: width)
            }
            .frame(width: width * CGFloat(expenseSegmentStripOrder.count), alignment: .leading)
            .offset(x: -CGFloat(pagerIndex) * width + dragOffset)
            .simultaneousGesture(pageDrag(width: width))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            pagerIndex = expenseSegmentStripOrder.firstIndex(of: selection) ?? 1
        }
        .onChange(of: selection) { newSelection in
            let idx = expenseSegmentStripOrder.firstIndex(of: newSelection) ?? 1
            guard idx != pagerIndex else { return }
            withAnimation(ExpensePagerMotion.spring) {
                dragOffset = 0
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

    private func pageDrag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 14, coordinateSpace: .local)
            .onChanged { value in
                let dx = value.translation.x
                let dy = value.translation.y

                if dragAxis == nil {
                    guard max(abs(dx), abs(dy)) > 10 else { return }
                    dragAxis = abs(dx) > abs(dy) ? .horizontal : .vertical
                }
                guard dragAxis == .horizontal else { return }

                let atLeft = pagerIndex == 0 && dx > 0
                let atRight = pagerIndex == expenseSegmentStripOrder.count - 1 && dx < 0
                dragOffset = (atLeft || atRight) ? dx * 0.20 : dx
            }
            .onEnded { value in
                let axis = dragAxis
                dragAxis = nil
                guard axis == .horizontal else {
                    dragOffset = 0
                    return
                }

                let dx = value.translation.x
                let predicted = value.predictedEndTranslation.x
                let threshold = width * 0.28
                var target = pagerIndex
                if dx < -threshold || predicted < -width * 0.45 {
                    target = min(pagerIndex + 1, expenseSegmentStripOrder.count - 1)
                } else if dx > threshold || predicted > width * 0.45 {
                    target = max(pagerIndex - 1, 0)
                }

                let newSelection = expenseSegmentStripOrder[target]
                withAnimation(ExpensePagerMotion.spring) {
                    dragOffset = 0
                    pagerIndex = target
                    selection = newSelection
                }
            }
    }
}
