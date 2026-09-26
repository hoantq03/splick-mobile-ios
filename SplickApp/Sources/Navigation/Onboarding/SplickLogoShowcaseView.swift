#if DEBUG
import SwiftUI
import DesignSystem

struct SplickLogoShowcaseView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                showcaseBlock(title: "Full lockup — Onboarding") {
                    SplickLogoMark(size: 300, layout: .fullLockup, style: .fullColor)
                        .padding(.vertical, 24)
                }

                showcaseBlock(title: "Mark — Splash / Login") {
                    SplickLogoMark(size: 120, layout: .markOnly, style: .fullColor)
                        .padding(40)
                }

                showcaseBlock(title: "Monochrome") {
                    SplickLogoMark(size: 100, layout: .markOnly, style: .monochrome)
                        .padding(40)
                }

                showcaseBlock(title: "Dark background") {
                    ZStack {
                        Color(hex: 0x12141A)
                        SplickLogoMark(size: 110, layout: .markOnly, style: .onDark)
                    }
                    .frame(height: 200)
                }
            }
            .padding()
        }
        .background(SplickTheme.Colors.secondaryBackground)
    }

    private func showcaseBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.textSecondary)
            content()
                .frame(maxWidth: .infinity)
                .background(SplickTheme.Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview("Splick Logo") {
    SplickLogoShowcaseView()
}
#endif
