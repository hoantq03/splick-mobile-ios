import SwiftUI

/// Reports a view's bounds converted to window (screen) coordinates — reliable for toolbar items.
struct SplickGlobalFrameReader: UIViewRepresentable {
    @Binding var frame: CGRect

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard uiView.window != nil else { return }
            let next = uiView.convert(uiView.bounds, to: nil)
            guard next.width > 1, next.height > 1, next != frame else { return }
            frame = next
        }
    }
}

public extension View {
    func splickGlobalFrame(_ frame: Binding<CGRect>) -> some View {
        background {
            SplickGlobalFrameReader(frame: frame)
        }
    }
}
