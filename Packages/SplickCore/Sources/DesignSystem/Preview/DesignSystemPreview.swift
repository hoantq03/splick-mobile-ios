import SwiftUI

#if DEBUG

#Preview("Buttons") {
    VStack(spacing: 16) {
        SplickButton("Primary Button", style: .primary) {}
        SplickButton("Secondary", style: .secondary) {}
        SplickButton("Destructive", style: .destructive) {}
        SplickButton("Ghost", style: .ghost) {}
        SplickButton("Loading...", isLoading: true) {}
        SplickButton("Disabled", isDisabled: true) {}
    }
    .padding()
}

#Preview("Text Fields") {
    VStack(spacing: 16) {
        SplickTextField("Email", text: .constant(""), icon: "envelope")
        SplickTextField("Password", text: .constant(""), isSecure: true, icon: "lock")
        SplickTextField("With Error", text: .constant("bad"), errorMessage: "Invalid input", icon: "exclamationmark.triangle")
    }
    .padding()
}

#Preview("Avatar") {
    HStack(spacing: 16) {
        AvatarView(name: "Nam Tran", size: .small)
        AvatarView(name: "Linh Pham", size: .medium)
        AvatarView(name: "Duc Nguyen", size: .large)
    }
    .padding()
}

#Preview("Empty State") {
    EmptyStateView(
        icon: "photo.on.rectangle.angled",
        title: "No Posts Yet",
        message: "Share a moment with your friends to get started!",
        actionTitle: "Take a Photo"
    ) {}
}

#Preview("Error State") {
    ErrorView(message: "Something went wrong. Please try again.") {}
}

#Preview("Loading") {
    LoadingView(message: "Loading your feed...")
}

#Preview("Card Modifier") {
    VStack(spacing: 16) {
        Text("This is a card")
            .frame(maxWidth: .infinity)
            .splickCard()

        HStack {
            Image(systemName: "star.fill")
            Text("Card with icon")
        }
        .frame(maxWidth: .infinity)
        .splickCard()
    }
    .padding()
}

#endif
