import XCTest
import SwiftUI
import UIKit
@testable import FeatureMedia

@MainActor
final class PhotoEditorViewModelTests: XCTestCase {
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }

    func testInitialState() {
        let image = createTestImage()
        let vm = PhotoEditorViewModel(sourceImage: image)

        XCTAssertNotNil(vm.baseImage)
        XCTAssertNil(vm.activeTool)
        XCTAssertTrue(vm.isChromeVisible)
        XCTAssertFalse(vm.canUndo)
        XCTAssertFalse(vm.canRedo)
        XCTAssertTrue(vm.textItems.isEmpty)
        XCTAssertTrue(vm.stickerItems.isEmpty)
        XCTAssertEqual(vm.selectedCropAspect, .original)
        XCTAssertEqual(vm.activeFilter, .none)
    }

    func testToolSelectionAndChromeVisibility() {
        let image = createTestImage()
        let vm = PhotoEditorViewModel(sourceImage: image)

        // Select text tool
        vm.selectTool(.text)
        XCTAssertEqual(vm.activeTool, .text)
        XCTAssertTrue(vm.isChromeVisible)

        // Select same tool toggles to view mode
        vm.selectTool(.text)
        XCTAssertNil(vm.activeTool)
        XCTAssertFalse(vm.isChromeVisible)

        // Show chrome again
        vm.showChrome()
        XCTAssertTrue(vm.isChromeVisible)

        // Enter view mode directly
        vm.enterViewMode()
        XCTAssertFalse(vm.isChromeVisible)
        XCTAssertNil(vm.activeTool)

        // Toggle chrome from tap when in view mode
        XCTAssertTrue(vm.shouldToggleChromeOnImageTap)
        vm.toggleChromeFromImageTap()
        XCTAssertTrue(vm.isChromeVisible)
    }

    func testRotateAndFlipTools() {
        let image = createTestImage()
        let vm = PhotoEditorViewModel(sourceImage: image)

        // Add a text item to verify rotation transforms it
        vm.addText(at: CGPoint(x: 0.2, y: 0.2))
        XCTAssertEqual(vm.textItems.count, 1)

        // Rotate tool
        vm.selectTool(.rotate)
        XCTAssertEqual(vm.activeTool, .rotate)
        // Check text item rotation updated
        XCTAssertEqual(vm.textItems.first?.rotation, .degrees(90))

        // Flip tool
        vm.selectTool(.flip)
        XCTAssertEqual(vm.activeTool, .flip)
    }

    func testTextItemOperationsAndUndoRedo() {
        let image = createTestImage()
        let vm = PhotoEditorViewModel(sourceImage: image)

        // Add text item
        vm.addText(at: CGPoint(x: 0.5, y: 0.5))
        XCTAssertEqual(vm.textItems.count, 1)
        XCTAssertTrue(vm.canUndo)
        let textId = vm.textItems[0].id
        XCTAssertEqual(vm.selectedTextID, textId)

        // Update text
        vm.updateText(textId, text: "Hello Splick")
        XCTAssertEqual(vm.textItems.first?.text, "Hello Splick")

        // Update scale and rotation
        vm.updateTextItemScale(id: textId, scale: 1.5)
        XCTAssertEqual(vm.textItems.first?.scale, 1.5)

        vm.updateTextItemRotation(id: textId, rotation: .degrees(45))
        XCTAssertEqual(vm.textItems.first?.rotation, .degrees(45))

        // Deselect text
        vm.deselectEditingText()
        XCTAssertNil(vm.selectedTextID)

        // Undo adding text
        vm.undo()
        XCTAssertTrue(vm.textItems.isEmpty)
        XCTAssertTrue(vm.canRedo)

        // Redo adding text
        vm.redo()
        XCTAssertEqual(vm.textItems.count, 1)

        // Remove text item
        vm.removeTextItem(textId)
        XCTAssertTrue(vm.textItems.isEmpty)
    }

    func testEmojiUsageAndAdjustments() {
        let image = createTestImage()
        let vm = PhotoEditorViewModel(sourceImage: image)

        vm.recordEmojiUsage("🔥")
        vm.recordEmojiUsage("✨")
        XCTAssertEqual(vm.recentEmojis.first, "✨")
        XCTAssertEqual(vm.recentEmojis[1], "🔥")

        // Re-recording emoji moves it to front
        vm.recordEmojiUsage("🔥")
        XCTAssertEqual(vm.recentEmojis.first, "🔥")

        // Adjustments
        var adj = ImageAdjustments.identity
        adj.exposure = 0.5
        adj.contrast = 1.2
        vm.setAdjustingLive(true)
        vm.setAdjustments(adj)
        XCTAssertEqual(vm.adjustments.exposure, 0.5)
        XCTAssertEqual(vm.adjustments.contrast, 1.2)
        vm.commitAdjustments()

        // Crop rect commitment
        vm.selectedCropAspect = .square
        vm.commitCropRect(CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5))
        XCTAssertNotNil(vm.normalizedCropRect)
    }

    func testBrightnessLevelIsSignedPercent() {
        XCTAssertEqual(EditorToolbar.brightnessLevel(0), "0")
        XCTAssertEqual(EditorToolbar.brightnessLevel(0.25), "+25")
        XCTAssertEqual(EditorToolbar.brightnessLevel(-0.4), "-40")
        XCTAssertEqual(EditorToolbar.brightnessLevel(1.4), "+100")
        XCTAssertEqual(EditorToolbar.brightnessLevel(-1.2), "-100")
    }
}
