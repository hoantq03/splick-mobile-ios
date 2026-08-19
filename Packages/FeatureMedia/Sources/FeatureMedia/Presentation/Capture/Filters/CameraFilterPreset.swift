import Foundation
import Localization

/// Built-in capture filters. Drop additional `.cube` files into `Resources/LUTs`
/// and register them here to ingest custom looks without a paid SDK.
enum CameraFilterPreset: String, CaseIterable, Identifiable, Equatable {
    case none
    case cinematic
    case vintage
    case vivid
    case beauty
    case ar

    var id: String { rawValue }

    var cubeResourceName: String? {
        switch self {
        case .cinematic: return "cinematic"
        case .vintage: return "vintage"
        case .vivid: return "vivid"
        case .none, .beauty, .ar: return nil
        }
    }

    var titleKey: L10nKey {
        switch self {
        case .none: return .mediaFilterNone
        case .cinematic: return .mediaFilterCinematic
        case .vintage: return .mediaFilterVintage
        case .vivid: return .mediaFilterVivid
        case .beauty: return .mediaFilterBeauty
        case .ar: return .mediaFilterAR
        }
    }

    var showsIntensitySlider: Bool {
        self == .beauty || cubeResourceName != nil
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
