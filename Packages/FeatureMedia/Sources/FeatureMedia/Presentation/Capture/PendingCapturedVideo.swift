import UIKit

/// Hold-to-record / boomerang clip that can navigate to compose before frames finish flushing.
///
/// Finger-up should open create-post immediately. Frames may still be draining off the
/// capture queue; encode starts only after [waitForFrames] returns.
public final class PendingCapturedVideo: @unchecked Sendable, Identifiable {
    public enum Failure: Error {
        case cancelled
        case tooShort
        case captureFailed
    }

    public let id: UUID
    public let pingPong: Bool
    public private(set) var previewImage: UIImage?

    private let lock = NSLock()
    private var frames: [UIImage]?
    private var failure: Failure?
    private var waiters: [CheckedContinuation<[UIImage], Error>] = []

    public init(
        id: UUID = UUID(),
        pingPong: Bool,
        previewImage: UIImage? = nil,
        frames: [UIImage]? = nil
    ) {
        self.id = id
        self.pingPong = pingPong
        self.previewImage = previewImage ?? frames?.first
        self.frames = frames
    }

    /// Convenience for tests / already-ready clips.
    public convenience init(
        id: UUID = UUID(),
        frames: [UIImage],
        pingPong: Bool,
        previewImage: UIImage? = nil
    ) {
        self.init(id: id, pingPong: pingPong, previewImage: previewImage, frames: frames)
    }

    public var isFramesReady: Bool {
        lock.lock()
        defer { lock.unlock() }
        return frames != nil || failure != nil
    }

    public func waitForFrames() async throws -> [UIImage] {
        lock.lock()
        if let failure {
            lock.unlock()
            throw failure
        }
        if let frames {
            lock.unlock()
            return frames
        }
        return try await withCheckedThrowingContinuation { continuation in
            waiters.append(continuation)
            lock.unlock()
        }
    }

    public func deliverFrames(_ frames: [UIImage]) {
        lock.lock()
        guard self.frames == nil, failure == nil else {
            lock.unlock()
            return
        }
        self.frames = frames
        if previewImage == nil {
            previewImage = frames.first
        }
        let waiters = self.waiters
        self.waiters = []
        lock.unlock()
        for waiter in waiters {
            waiter.resume(returning: frames)
        }
    }

    public func fail(_ error: Failure = .captureFailed) {
        lock.lock()
        guard frames == nil, failure == nil else {
            lock.unlock()
            return
        }
        failure = error
        let waiters = self.waiters
        self.waiters = []
        lock.unlock()
        for waiter in waiters {
            waiter.resume(throwing: error)
        }
    }
}
