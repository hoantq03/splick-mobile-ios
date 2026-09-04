import SwiftUI
import Localization

/// Thumbnail that opens a full-screen, pinch-zoomable preview on tap.
public struct SplickExpandableRemoteImage: View {
    let url: URL
    var maxHeight: CGFloat
    var accessibilityLabel: String

    @EnvironmentObject private var languageService: LanguageService
    @State private var isExpanded = false

    public init(url: URL, maxHeight: CGFloat, accessibilityLabel: String) {
        self.url = url
        self.maxHeight = maxHeight
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        Button {
            isExpanded = true
        } label: {
            RemoteImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: maxHeight)
                        .frame(maxWidth: .infinity)
                case .failure:
                    Image(systemName: "qrcode")
                        .font(.largeTitle)
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                default:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 80)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isImage)
        .splickWindowFullScreenCover(isPresented: $isExpanded) {
            SplickFullscreenRemoteImageOverlay(
                url: url,
                closeLabel: languageService.text(.commonClose),
                onDismiss: { isExpanded = false }
            )
        }
    }
}

struct SplickFullscreenRemoteImageOverlay: View {
    let url: URL
    let closeLabel: String
    var onDismiss: () -> Void

    @State private var scale: CGFloat = 1
    @GestureState private var pinchScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            RemoteImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale * pinchScale)
                        .offset(
                            x: offset.width + dragOffset.width,
                            y: offset.height + dragOffset.height
                        )
                        .gesture(pinchGesture)
                        .simultaneousGesture(panGesture)
                        .onTapGesture(count: 2, perform: toggleZoom)
                case .failure:
                    Image(systemName: "qrcode")
                        .font(.system(size: 64))
                        .foregroundStyle(.white)
                default:
                    ProgressView()
                        .tint(.white)
                }
            }
            .padding(SplickTheme.Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel(closeLabel)
                    .padding(.trailing, SplickTheme.Spacing.md)
                    .padding(.top, SplickTheme.Spacing.sm)
                }
                Spacer()
            }
        }
        .statusBarHidden(true)
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .updating($pinchScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                scale = min(max(scale * value, 1), 4)
                if scale <= 1.01 {
                    scale = 1
                    offset = .zero
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                guard scale > 1.01 else { return }
                state = value.translation
            }
            .onEnded { value in
                if scale <= 1.01 {
                    if value.translation.height > 80 {
                        onDismiss()
                    }
                    return
                }
                offset = CGSize(
                    width: offset.width + value.translation.width,
                    height: offset.height + value.translation.height
                )
            }
    }

    private func toggleZoom() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            if scale > 1.01 {
                scale = 1
                offset = .zero
            } else {
                scale = 2.2
            }
        }
    }
}
