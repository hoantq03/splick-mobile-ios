import CoreGraphics
import Foundation
import UIKit

/// In-memory edit history for each photo in the current compose draft.
/// Cleared when the draft is posted or cancelled — not when leaving the editor.
@MainActor
public final class PhotoEditorSessionStore {
    public static let shared = PhotoEditorSessionStore()

    private var sessions: [UUID: PhotoEditorSession] = [:]
    private var pendingSessionIDs: [UUID] = []

    private init() {}

    func session(for id: UUID) -> PhotoEditorSession? {
        sessions[id]
    }

    func save(_ session: PhotoEditorSession, for id: UUID) {
        sessions[id] = session
    }

    public func markPending(_ id: UUID) {
        pendingSessionIDs.append(id)
    }

    public func takePendingSessionID() -> UUID? {
        guard !pendingSessionIDs.isEmpty else { return nil }
        return pendingSessionIDs.removeFirst()
    }

    public func remove(_ id: UUID) {
        sessions.removeValue(forKey: id)
        pendingSessionIDs.removeAll { $0 == id }
    }

    public func removeAll() {
        sessions.removeAll()
        pendingSessionIDs.removeAll()
    }
}

struct PhotoEditorSession {
    let originalImage: UIImage
    let undoStack: [EditState]
    let redoStack: [EditState]
    let drawingCanvasSize: CGSize
    let selectedCropAspect: CropAspectPreset
}
