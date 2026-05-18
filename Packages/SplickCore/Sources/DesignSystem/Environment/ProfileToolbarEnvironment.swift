import SwiftUI
import SplickDomain

private struct OpenProfileActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private struct CurrentUserSummaryKey: EnvironmentKey {
    static let defaultValue: UserSummary? = nil
}

extension EnvironmentValues {
    public var openProfileSettings: (() -> Void)? {
        get { self[OpenProfileActionKey.self] }
        set { self[OpenProfileActionKey.self] = newValue }
    }

    public var currentUserSummary: UserSummary? {
        get { self[CurrentUserSummaryKey.self] }
        set { self[CurrentUserSummaryKey.self] = newValue }
    }
}

extension View {
    /// Avatar button top-leading; use with `.navigationTitle(...)` for the screen title.
    public func splickProfileToolbar() -> some View {
        modifier(SplickProfileToolbarModifier())
    }
}

private struct SplickProfileToolbarModifier: ViewModifier {
    @Environment(\.openProfileSettings) private var openProfileSettings
    @Environment(\.currentUserSummary) private var currentUserSummary

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let openProfileSettings, let user = currentUserSummary {
                        Button(action: openProfileSettings) {
                            AvatarView(
                                imageURL: user.avatarURL,
                                name: user.displayName,
                                size: .small
                            )
                            .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Profile settings")
                    }
                }
            }
    }
}
