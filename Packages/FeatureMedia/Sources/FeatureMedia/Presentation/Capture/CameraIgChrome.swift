import DesignSystem
import Localization
import SwiftUI

enum CameraPublishMode: String, CaseIterable, Identifiable {
    case post
    case story
    case reels

    var id: String { rawValue }
}

struct CameraLeftToolbar: View {
    @EnvironmentObject private var languageService: LanguageService
    let onTextMode: () -> Void
    let onBoomerang: () -> Void
    let onLayout: () -> Void
    let onHandsFree: () -> Void

    var body: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            sideTool(icon: "textformat", label: .mediaCameraToolText, action: onTextMode)
            sideTool(icon: "infinity", label: .mediaCameraToolBoomerang, action: onBoomerang)
            sideTool(icon: "square.grid.2x2", label: .mediaCameraToolLayout, action: onLayout)
            sideTool(icon: "timer", label: .mediaCameraToolHandsFree, action: onHandsFree)
        }
        .padding(.leading, SplickTheme.Spacing.sm)
    }

    private func sideTool(icon: String, label: L10nKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.black.opacity(0.28)))

                Text(languageService.text(label))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 56)
        }
        .buttonStyle(.plain)
    }
}

struct CameraModeStrip: View {
    @EnvironmentObject private var languageService: LanguageService
    let selected: CameraPublishMode
    let onSelect: (CameraPublishMode) -> Void
    let onComingSoon: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            modeTab(.post, label: .mediaCameraModePost)
            modeTab(.story, label: .mediaCameraModeStory, disabled: true)
            modeTab(.reels, label: .mediaCameraModeReels, disabled: true)
        }
        .padding(.bottom, SplickTheme.Spacing.xs)
    }

    private func modeTab(_ mode: CameraPublishMode, label: L10nKey, disabled: Bool = false) -> some View {
        let isSelected = selected == mode
        return Button {
            if disabled {
                onComingSoon()
            } else {
                onSelect(mode)
            }
        } label: {
            Text(languageService.text(label))
                .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
        }
        .buttonStyle(.plain)
    }
}

enum CameraBottomBarMetrics {
    static let shutterDiameter: CGFloat = 72
    static let sideControlDiameter: CGFloat = 44
    static let galleryDiameter: CGFloat = 50
}

/// Capsule label centered above the shutter — matches Instagram filter name chrome.
struct CameraFilterNameBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(Color.black.opacity(0.42))
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                    }
            }
    }
}

/// Current optical zoom. Tap to jump between 1× and 2×.
struct CameraZoomBadge: View {
    @EnvironmentObject private var languageService: LanguageService
    let zoom: CGFloat
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Text(CameraZoom.label(zoom))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(Color.black.opacity(0.45))
                        .overlay {
                            Capsule()
                                .stroke(Color.white.opacity(0.22), lineWidth: 0.5)
                        }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(languageService.text(.mediaZoomA11y))
    }
}

/// Single filter orb (same diameter as shutter). Swipe or tap to cycle presets.
struct FilterCarouselBar: View {
    @EnvironmentObject private var languageService: LanguageService
    @Binding var preset: CameraFilterPreset
    var catalogItems: [FilterCatalogItem] = []

    private var selectablePresets: [CameraFilterPreset] {
        CameraFilterPreset.allCases.filter { $0 != .ar }
    }

    var body: some View {
        filterOrb
            .frame(width: CameraBottomBarMetrics.shutterDiameter, height: CameraBottomBarMetrics.shutterDiameter)
            .contentShape(Circle())
            .gesture(swipeGesture)
            .onTapGesture { cycleFilter(forward: true) }
            .accessibilityLabel(languageService.text(preset.titleKey))
            .accessibilityAddTraits(.isButton)
    }

    private var filterOrb: some View {
        ZStack {
            Circle()
                .fill(CameraFilterSwatch.gradient(for: preset))
            if let thumbnailURL = catalogThumbnailURL(for: preset) {
                AsyncImage(url: thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        EmptyView()
                    }
                }
            }
        }
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color.white.opacity(preset == .none ? 0.28 : 0.55), lineWidth: 2.5)
        }
        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                if value.translation.width <= -24 {
                    cycleFilter(forward: true)
                } else if value.translation.width >= 24 {
                    cycleFilter(forward: false)
                }
            }
    }

    private func cycleFilter(forward: Bool) {
        let presets = selectablePresets
        guard let index = presets.firstIndex(of: preset) else {
            preset = presets.first ?? .none
            return
        }
        let nextIndex = forward
            ? (index + 1) % presets.count
            : (index - 1 + presets.count) % presets.count
        withAnimation(.easeInOut(duration: 0.18)) {
            preset = presets[nextIndex]
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func catalogThumbnailURL(for preset: CameraFilterPreset) -> URL? {
        catalogItems.first { mapCatalogSlug($0.slug) == preset }?.thumbnailURL
    }

    private func mapCatalogSlug(_ slug: String) -> CameraFilterPreset? {
        CameraFilterPreset(rawValue: slug.replacingOccurrences(of: "-", with: ""))
            ?? CameraFilterPreset.allCases.first { $0.rawValue == slug }
    }
}

enum CameraFilterSwatch {
    static func gradient(for preset: CameraFilterPreset) -> LinearGradient {
        switch preset {
        case .none:
            return LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .cinematic:
            return LinearGradient(colors: [Color(red: 0.2, green: 0.15, blue: 0.35), Color(red: 0.45, green: 0.35, blue: 0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .vintage:
            return LinearGradient(colors: [Color(red: 0.55, green: 0.38, blue: 0.22), Color(red: 0.78, green: 0.62, blue: 0.42)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .vivid:
            return LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .fade:
            return LinearGradient(colors: [.gray.opacity(0.35), .white.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .blackAndWhite:
            return LinearGradient(colors: [.black, .white], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .warm:
            return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .cool:
            return LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .beauty:
            return LinearGradient(colors: [.pink.opacity(0.7), .purple.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .ar:
            return LinearGradient(colors: [.mint, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}
