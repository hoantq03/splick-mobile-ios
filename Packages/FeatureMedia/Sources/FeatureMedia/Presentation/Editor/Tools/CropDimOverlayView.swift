import UIKit
import SwiftUI

struct CropDimOverlayView: UIViewRepresentable {
    var cropFrame: CGRect

    func makeUIView(context: Context) -> CropDimHoleView {
        CropDimHoleView()
    }

    func updateUIView(_ uiView: CropDimHoleView, context: Context) {
        uiView.cropFrame = cropFrame
    }
}

final class CropDimHoleView: UIView {
    var cropFrame: CGRect = .zero {
        didSet { updatePath() }
    }

    private let dimLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        dimLayer.fillRule = .evenOdd
        dimLayer.fillColor = UIColor.black.withAlphaComponent(0.55).cgColor
        layer.addSublayer(dimLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        dimLayer.frame = bounds
        updatePath()
    }

    private func updatePath() {
        let path = CGMutablePath()
        path.addRect(bounds)
        path.addRect(cropFrame)
        dimLayer.path = path
    }
}
