import Localization
import SwiftUI

struct FilterStripView: View {
    @EnvironmentObject private var languageService: LanguageService
    @Binding var preset: CameraFilterPreset
    @Binding var intensity: Float
    @Binding var arEffect: ARFaceEffect
    var faceTrackingSupported: Bool

    var body: some View {
        VStack(spacing: 10) {
            if preset.showsIntensitySlider {
                HStack(spacing: 10) {
                    Text(languageService.text(.mediaFilterIntensity))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Slider(value: Binding(
                        get: { Double(intensity) },
                        set: { intensity = Float($0) }
                    ), in: 0.15...1)
                    .tint(.white)
                }
                .padding(.horizontal, 16)
            }

            if preset == .ar {
                HStack(spacing: 8) {
                    ForEach(ARFaceEffect.allCases) { effect in
                        Button {
                            arEffect = effect
                        } label: {
                            Text(languageService.text(effect.titleKey))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(arEffect == effect ? .black : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(arEffect == effect ? Color.white : Color.white.opacity(0.18))
                                )
                        }
                    }
                    if !faceTrackingSupported {
                        Text(languageService.text(.mediaFilterARUnsupported))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 16)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CameraFilterPreset.allCases) { item in
                        Button {
                            preset = item
                        } label: {
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(swatch(for: item))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle().stroke(preset == item ? Color.white : Color.white.opacity(0.25), lineWidth: 2)
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
    }

    private func swatch(for preset: CameraFilterPreset) -> LinearGradient {
        switch preset {
        case .none:
            return LinearGradient(colors: [.gray, .white], startPoint: .top, endPoint: .bottom)
        case .cinematic:
            return LinearGradient(colors: [Color(red: 0.15, green: 0.22, blue: 0.38), Color(red: 0.72, green: 0.55, blue: 0.32)], startPoint: .top, endPoint: .bottom)
        case .vintage:
            return LinearGradient(colors: [Color(red: 0.55, green: 0.38, blue: 0.22), Color(red: 0.85, green: 0.72, blue: 0.48)], startPoint: .top, endPoint: .bottom)
        case .vivid:
            return LinearGradient(colors: [.pink, .orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .fade:
            return LinearGradient(colors: [Color(white: 0.55), Color(white: 0.9)], startPoint: .top, endPoint: .bottom)
        case .blackAndWhite:
            return LinearGradient(colors: [.black, .white], startPoint: .top, endPoint: .bottom)
        case .warm:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom)
        case .cool:
            return LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)
        case .beauty:
            return LinearGradient(colors: [Color(red: 1, green: 0.75, blue: 0.78), .white], startPoint: .top, endPoint: .bottom)
        case .ar:
            return LinearGradient(colors: [.purple, .cyan], startPoint: .top, endPoint: .bottom)
        }
    }
}
