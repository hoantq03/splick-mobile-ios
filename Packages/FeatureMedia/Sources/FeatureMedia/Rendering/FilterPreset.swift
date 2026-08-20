import Foundation
import Localization

/// Color-grade catalog shared by live camera and the photo editor.
public enum FilterPreset: String, CaseIterable, Identifiable, Equatable {
    case none
    case cinematic
    case vintage
    case vivid
    case fade
    case blackAndWhite
    case warm
    case cool

    public var id: String { rawValue }

    public var cubeResourceName: String? {
        switch self {
        case .cinematic: return "cinematic"
        case .vintage: return "vintage"
        case .vivid: return "vivid"
        case .fade: return "fade"
        case .none, .blackAndWhite, .warm, .cool: return nil
        }
    }

    var titleKey: L10nKey {
        switch self {
        case .none: return .mediaFilterNone
        case .cinematic: return .mediaFilterCinematic
        case .vintage: return .mediaFilterVintage
        case .vivid: return .mediaFilterVivid
        case .fade: return .mediaFilterFade
        case .blackAndWhite: return .mediaFilterBlackAndWhite
        case .warm: return .mediaFilterWarm
        case .cool: return .mediaFilterCool
        }
    }

    init(_ camera: CameraFilterPreset) {
        switch camera {
        case .none: self = .none
        case .cinematic: self = .cinematic
        case .vintage: self = .vintage
        case .vivid: self = .vivid
        case .fade: self = .fade
        case .blackAndWhite: self = .blackAndWhite
        case .warm: self = .warm
        case .cool: self = .cool
        case .beauty, .ar: self = .none
        }
    }
}
