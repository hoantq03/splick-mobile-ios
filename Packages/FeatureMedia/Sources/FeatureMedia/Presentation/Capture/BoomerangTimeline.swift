import CoreGraphics
import Foundation

enum BoomerangTimeline {
    /// Hold-to-record and boomerang encode at 24 fps.
    static let targetFPS = 24
    /// 30s × 24fps.
    static let maxFrames = 720
    static let minFrames = 6
    static let captureDuration: TimeInterval = 30
    static let minFrameInterval: TimeInterval = 1 / Double(targetFPS)
    /// 540 keeps feed quality acceptable and roughly halves encode cost vs 720.
    static let maxLongSide: CGFloat = 540

    /// Forward then reverse, omitting the duplicated endpoints so looping stays smooth.
    static func pingPongIndices(frameCount: Int) -> [Int] {
        guard frameCount > 1 else { return Array(0..<max(frameCount, 0)) }
        let forward = Array(0..<frameCount)
        let reverse = stride(from: frameCount - 2, through: 1, by: -1).map { $0 }
        return forward + reverse
    }
}
