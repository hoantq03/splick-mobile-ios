import ARKit
import Combine
import DesignSystem
import SceneKit
import SwiftUI
import UIKit

final class ARCaptureHandle: ObservableObject {
    weak var renderer: FaceOverlayRenderer?

    func snapshot() -> UIImage? {
        renderer?.snapshotImage()
    }
}

struct ARCameraView: UIViewRepresentable {
    @Binding var effect: ARFaceEffect
    var captureHandle: ARCaptureHandle

    func makeCoordinator() -> FaceOverlayRenderer {
        FaceOverlayRenderer()
    }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.automaticallyUpdatesLighting = true
        view.clipsToBounds = true
        view.layer.cornerRadius = SplickTheme.CornerRadius.card
        view.layer.cornerCurve = .continuous
        view.layer.masksToBounds = true
        view.delegate = context.coordinator
        context.coordinator.effect = effect
        context.coordinator.sceneView = view
        captureHandle.renderer = context.coordinator
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        view.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.effect = effect
    }

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: FaceOverlayRenderer) {
        uiView.session.pause()
    }
}

final class FaceOverlayRenderer: NSObject, ARSCNViewDelegate {
    var effect: ARFaceEffect = .glasses
    weak var sceneView: ARSCNView?

    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard anchor is ARFaceAnchor else { return nil }
        let node = SCNNode()
        node.addChildNode(makeGlassesNode())
        node.addChildNode(makeSparkleNode())
        applyEffectVisibility(on: node)
        return node
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        applyEffectVisibility(on: node)
    }

    func snapshotImage() -> UIImage? {
        sceneView?.snapshot()
    }

    private func applyEffectVisibility(on node: SCNNode) {
        node.childNode(withName: "glasses", recursively: false)?.isHidden = effect != .glasses
        node.childNode(withName: "sparkle", recursively: false)?.isHidden = effect != .sparkle
    }

    private func makeGlassesNode() -> SCNNode {
        let left = SCNSphere(radius: 0.028)
        left.firstMaterial?.diffuse.contents = UIColor.black.withAlphaComponent(0.55)
        left.firstMaterial?.metalness.contents = 0.4
        let right = left.copy() as! SCNSphere
        let leftNode = SCNNode(geometry: left)
        leftNode.position = SCNVector3(-0.033, 0.02, 0.05)
        let rightNode = SCNNode(geometry: right)
        rightNode.position = SCNVector3(0.033, 0.02, 0.05)
        let bridge = SCNBox(width: 0.018, height: 0.004, length: 0.004, chamferRadius: 0.001)
        bridge.firstMaterial?.diffuse.contents = UIColor.white
        let bridgeNode = SCNNode(geometry: bridge)
        bridgeNode.position = SCNVector3(0, 0.02, 0.05)
        let parent = SCNNode()
        parent.name = "glasses"
        parent.addChildNode(leftNode)
        parent.addChildNode(rightNode)
        parent.addChildNode(bridgeNode)
        return parent
    }

    private func makeSparkleNode() -> SCNNode {
        let parent = SCNNode()
        parent.name = "sparkle"
        let offsets: [SCNVector3] = [
            SCNVector3(0, 0.09, 0.04),
            SCNVector3(-0.07, 0.06, 0.03),
            SCNVector3(0.07, 0.06, 0.03),
        ]
        for offset in offsets {
            let star = SCNSphere(radius: 0.008)
            star.firstMaterial?.diffuse.contents = UIColor.systemYellow
            star.firstMaterial?.emission.contents = UIColor.systemYellow
            let node = SCNNode(geometry: star)
            node.position = offset
            parent.addChildNode(node)
        }
        return parent
    }
}

/// Vision-based overlay when TrueDepth / ARFaceTracking is unavailable.
struct VisionFaceOverlayView: View {
    var effect: ARFaceEffect
    var faceRect: CGRect?

    var body: some View {
        GeometryReader { geo in
            if let faceRect {
                let frame = CGRect(
                    x: faceRect.minX * geo.size.width,
                    y: (1 - faceRect.maxY) * geo.size.height,
                    width: faceRect.width * geo.size.width,
                    height: faceRect.height * geo.size.height
                )
                ZStack {
                    if effect == .glasses {
                        HStack(spacing: frame.width * 0.08) {
                            Capsule().fill(Color.black.opacity(0.45))
                            Capsule().fill(Color.black.opacity(0.45))
                        }
                        .frame(width: frame.width * 0.72, height: frame.height * 0.18)
                        .position(x: frame.midX, y: frame.minY + frame.height * 0.42)
                    } else {
                        HStack(spacing: 10) {
                            Circle().fill(Color.yellow)
                            Circle().fill(Color.yellow)
                            Circle().fill(Color.yellow)
                        }
                        .frame(width: frame.width * 0.5, height: 10)
                        .position(x: frame.midX, y: frame.minY + 8)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
