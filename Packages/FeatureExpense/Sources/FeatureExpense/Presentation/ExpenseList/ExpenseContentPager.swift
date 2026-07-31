import SwiftUI
import DesignSystem

private enum ExpensePagerMotion {
    /// Match main-tab slide: no spring overshoot mid/end hitch.
    static let slide = Animation.easeInOut(duration: 0.28)
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
    @State private var activatedSegments: Set<ExpenseContentSegment> = [.overview]
    @State private var transitionGeneration: Int = 0

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
            .animation(dragAxis == nil ? ExpensePagerMotion.slide : nil, value: pagerIndex)
            .simultaneousGesture(pageDrag(width: width))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            pagerIndex = expenseSegmentStripOrder.firstIndex(of: selection) ?? 1
            activatedSegments.insert(selection)
            prewarmRemainingSegments()
        }
        .onChange(of: selection) { newSelection in
            moveToSegment(newSelection)
        }
    }

    private func prewarmRemainingSegments() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard activatedSegments.count < expenseSegmentStripOrder.count else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                activatedSegments.formUnion(expenseSegmentStripOrder)
            }
        }
    }

    private func moveToSegment(_ newSelection: ExpenseContentSegment) {
        let idx = expenseSegmentStripOrder.firstIndex(of: newSelection) ?? 1
        guard idx != pagerIndex else {
            activatedSegments.insert(newSelection)
            return
        }

        let from = pagerIndex
        let range = min(from, idx)...max(from, idx)
        let needsMount = range.contains { !activatedSegments.contains(expenseSegmentStripOrder[$0]) }

        transitionGeneration += 1
        let generation = transitionGeneration

        if needsMount {
            var mountTransaction = Transaction()
            mountTransaction.disablesAnimations = true
            withTransaction(mountTransaction) {
                for i in range {
                    activatedSegments.insert(expenseSegmentStripOrder[i])
                }
            }
            Task { @MainActor in
                await Task.yield()
                guard generation == transitionGeneration else { return }
                withAnimation(ExpensePagerMotion.slide) {
                    dragOffset = 0
                    pagerIndex = idx
                }
            }
        } else {
            withAnimation(ExpensePagerMotion.slide) {
                dragOffset = 0
                pagerIndex = idx
            }
        }
    }

    @ViewBuilder
    private func page<Content: View>(
        _ content: () -> Content,
        segment: ExpenseContentSegment,
        width: CGFloat
    ) -> some View {
        Group {
            if activatedSegments.contains(segment) {
                content()
                    .transaction { $0.animation = nil }
            } else {
                Color.clear
            }
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .environment(\.scrollChromeTrackingEnabled, selection == segment)
        .allowsHitTesting(selection == segment)
    }

    private func pageDrag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 14, coordinateSpace: .local)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height

                if dragAxis == nil {
                    guard max(abs(dx), abs(dy)) > 10 else { return }
                    dragAxis = abs(dx) > abs(dy) ? .horizontal : .vertical
                    if dragAxis == .horizontal {
                        // Ensure destination exists before interactive drag reveals it.
                        let neighbor = dx < 0
                            ? min(pagerIndex + 1, expenseSegmentStripOrder.count - 1)
                            : max(pagerIndex - 1, 0)
                        activatedSegments.insert(expenseSegmentStripOrder[neighbor])
                    }
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

                let dx = value.translation.width
                let predicted = value.predictedEndTranslation.width
                let threshold = width * 0.28
                var target = pagerIndex
                if dx < -threshold || predicted < -width * 0.45 {
                    target = min(pagerIndex + 1, expenseSegmentStripOrder.count - 1)
                } else if dx > threshold || predicted > width * 0.45 {
                    target = max(pagerIndex - 1, 0)
                }

                let newSelection = expenseSegmentStripOrder[target]
                activatedSegments.insert(newSelection)
                withAnimation(ExpensePagerMotion.slide) {
                    dragOffset = 0
                    pagerIndex = target
                    selection = newSelection
                }
            }
    }
}
