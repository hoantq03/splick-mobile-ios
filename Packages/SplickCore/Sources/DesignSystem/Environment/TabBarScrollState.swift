import SwiftUI

@MainActor
public final class TabBarScrollState: ObservableObject {
    @Published public private(set) var isVisible = true

    private var lastOffset: CGFloat = 0
    private let hideThreshold: CGFloat = 8
    private let showAtTopThreshold: CGFloat = 24

    public init() {}

    public func updateScrollOffset(_ offset: CGFloat) {
        if offset <= showAtTopThreshold {
            setVisible(true)
            lastOffset = offset
            return
        }

        let delta = offset - lastOffset
        if delta > hideThreshold {
            setVisible(false)
        } else if delta < -hideThreshold {
            setVisible(true)
        }
        lastOffset = offset
    }

    public func reset() {
        lastOffset = 0
        setVisible(true)
    }

    public func show() {
        setVisible(true)
    }

    public func hide() {
        setVisible(false)
    }

    private func setVisible(_ visible: Bool) {
        guard isVisible != visible else { return }
        isVisible = visible
    }
}

private struct TabBarScrollStateKey: EnvironmentKey {
    static let defaultValue: TabBarScrollState? = nil
}

extension EnvironmentValues {
    public var tabBarScrollState: TabBarScrollState? {
        get { self[TabBarScrollStateKey.self] }
        set { self[TabBarScrollStateKey.self] = newValue }
    }
}

public struct TabBarHideOnScrollModifier: ViewModifier {
    @Environment(\.tabBarScrollState) private var tabBarScrollState

    public init() {}

    public func body(content: Content) -> some View {
        if let tabBarScrollState {
            if #available(iOS 18.0, *) {
                content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top
                } action: { _, offset in
                    tabBarScrollState.updateScrollOffset(offset)
                }
            } else {
                content
            }
        } else {
            content
        }
    }
}

extension View {
    public func tabBarHideOnScroll() -> some View {
        modifier(TabBarHideOnScrollModifier())
    }
}
