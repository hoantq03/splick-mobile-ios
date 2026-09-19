import CoreGraphics
import Foundation

enum BoomerangTimeline {
    /// Lower FPS keeps hold-to-record feel while cutting encode time after release.
    static let targetFPS = 12
    /// 5s × 12fps.
    static let maxFrames = 60
    static let minFrames = 6
    static let captureDuration: TimeInterval = 5
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
