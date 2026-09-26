import CoreGraphics
import Foundation

public enum BoomerangTimeline {
    /// Hold-to-record and boomerang encode at 24 fps.
    public static let targetFPS = 24
    /// 30s × 24fps.
    public static let maxFrames = 720
    public static let minFrames = 6
    public static let captureDuration: TimeInterval = 30
    static let minFrameInterval: TimeInterval = 1 / Double(targetFPS)
    /// ~720p long side for hold-to-record / boomerang (HD feed quality).
    static let maxLongSide: CGFloat = 720

    /// Target average bitrate for H.264 encode (~0.4 bits/pixel/frame, clamped for 720p).
    static func averageBitRate(width: Int, height: Int, fps: Int = targetFPS) -> Int {
        let pixels = max(width, 1) * max(height, 1)
        let raw = pixels * max(fps, 1) * 4 / 10
        return min(max(raw, 1_200_000), 5_000_000)
    }

    /// Forward then reverse, omitting the duplicated endpoints so looping stays smooth.
    public static func pingPongIndices(frameCount: Int) -> [Int] {
        guard frameCount > 1 else { return Array(0..<max(frameCount, 0)) }
        let forward = Array(0..<frameCount)
        let reverse = stride(from: frameCount - 2, through: 1, by: -1).map { $0 }
        return forward + reverse
    }
}
