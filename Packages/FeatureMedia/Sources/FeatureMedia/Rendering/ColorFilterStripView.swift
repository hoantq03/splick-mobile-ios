import Localization
import SwiftUI

/// Horizontal color-grade chips used by the photo editor (and reusable by camera).
struct ColorFilterStripView: View {
    @EnvironmentObject private var languageService: LanguageService
    @Binding var preset: FilterPreset

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(FilterPreset.allCases) { item in
                    Button {
                        preset = item
                    } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(swatch(for: item))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle().stroke(
                                        preset == item ? Color.white : Color.white.opacity(0.25),
                                        lineWidth: 2
                                    )
                                )
                            Text(languageService.text(item.titleKey))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        .frame(width: 64)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func swatch(for preset: FilterPreset) -> LinearGradient {
        switch preset {
        case .none:
            return LinearGradient(colors: [.gray, .white], startPoint: .top, endPoint: .bottom)
        case .cinematic:
            return LinearGradient(
                colors: [Color(red: 0.15, green: 0.22, blue: 0.38), Color(red: 0.72, green: 0.55, blue: 0.32)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .vintage:
            return LinearGradient(
                colors: [Color(red: 0.55, green: 0.38, blue: 0.22), Color(red: 0.85, green: 0.72, blue: 0.48)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .vivid:
            return LinearGradient(colors: [.pink, .orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .fade:
            return LinearGradient(colors: [Color(white: 0.55), Color(white: 0.9)], startPoint: .top, endPoint: .bottom)
        case .blackAndWhite:
            return LinearGradient(colors: [.black, .white], startPoint: .top, endPoint: .bottom)
        case .warm:
            return LinearGradient(colors: [Color.orange, Color.yellow], startPoint: .top, endPoint: .bottom)
        case .cool:
            return LinearGradient(colors: [Color.cyan, Color.blue], startPoint: .top, endPoint: .bottom)
        }
    }
}
