import SwiftUI

public enum WidgetColors {
    public static let primaryStart = Color(red: 0.357, green: 0.424, blue: 1.0)
    public static let primaryEnd = Color(red: 0.165, green: 0.616, blue: 0.561)
    public static let success = Color(red: 0.153, green: 0.682, blue: 0.376)
    public static let error = Color(red: 0.922, green: 0.341, blue: 0.341)
    public static let warning = Color(red: 0.949, green: 0.600, blue: 0.290)

    public static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [primaryStart, primaryEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

public struct WidgetPlaceholderView: View {
    private let title: String
    private let systemImage: String

    public init(title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    public var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(WidgetColors.brandGradient)
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .padding()
        }
    }
}

public struct WidgetBrandHeader: View {
    private let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.caption2.weight(.bold))
            Text(title)
                .font(.caption.weight(.semibold))
            Spacer(minLength: 0)
        }
        .foregroundStyle(WidgetColors.primaryStart)
    }
}

public struct WidgetEmptyStateView: View {
    private let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray")
                .font(.title3)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
