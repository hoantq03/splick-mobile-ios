import XCTest
import UIKit
@testable import FeatureMedia

@MainActor
final class PhotoEditorSessionStoreTests: XCTestCase {
    override func tearDown() {
        PhotoEditorSessionStore.shared.removeAll()
        super.tearDown()
    }

    func testSaveRestoreAndPendingSessionId() {
        let id = UUID()
        let image = UIImage()
        let session = PhotoEditorSession(
            originalImage: image,
            undoStack: [EditState.initial(filter: .vivid)],
            redoStack: [],
            drawingCanvasSize: .zero,
            selectedCropAspect: .original
        )
        PhotoEditorSessionStore.shared.save(session, for: id)
        PhotoEditorSessionStore.shared.markPending(id)

        XCTAssertEqual(PhotoEditorSessionStore.shared.session(for: id)?.undoStack.count, 1)
        XCTAssertEqual(PhotoEditorSessionStore.shared.takePendingSessionID(), id)
        XCTAssertNil(PhotoEditorSessionStore.shared.takePendingSessionID())

        PhotoEditorSessionStore.shared.removeAll()
        XCTAssertNil(PhotoEditorSessionStore.shared.session(for: id))
    }
}
