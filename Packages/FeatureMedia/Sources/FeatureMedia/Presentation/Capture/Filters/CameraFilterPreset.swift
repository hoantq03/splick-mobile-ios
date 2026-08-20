import Foundation
import Localization

/// Built-in capture filters. Drop additional `.cube` files into `Resources/LUTs`
/// and register them on `FilterPreset` to ingest custom looks without a paid SDK.
enum CameraFilterPreset: String, CaseIterable, Identifiable, Equatable {
    case none
    case cinematic
    case vintage
    case vivid
    case fade
    case blackAndWhite
    case warm
    case cool
    case beauty
    case ar

    var id: String { rawValue }

    var cubeResourceName: String? {
        FilterPreset(self).cubeResourceName
    }

    var titleKey: L10nKey {
        switch self {
        case .beauty: return .mediaFilterBeauty
        case .ar: return .mediaFilterAR
        default: return FilterPreset(self).titleKey
        }
    }

    var showsIntensitySlider: Bool {
        self == .beauty || cubeResourceName != nil || self == .blackAndWhite || self == .warm || self == .cool
    }
}

enum ARFaceEffect: String, CaseIterable, Identifiable, Equatable {
    case glasses
    case sparkle

    var id: String { rawValue }

    var titleKey: L10nKey {
        switch self {
        case .glasses: return .mediaFilterARGlasses
        case .sparkle: return .mediaFilterARSparkle
        }
    }
}
