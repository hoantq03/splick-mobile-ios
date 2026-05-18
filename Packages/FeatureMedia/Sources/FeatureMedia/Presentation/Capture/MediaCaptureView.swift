import SwiftUI
import DesignSystem

public struct MediaCaptureView: View {
    let onMediaCaptured: (CapturedMedia) -> Void
    let onCancel: () -> Void

    @StateObject private var camera = CameraSessionModel()
    @State private var showAlbum = false
    @State private var previewSize: CGSize = .zero

    public init(
        onMediaCaptured: @escaping (CapturedMedia) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onMediaCaptured = onMediaCaptured
        self.onCancel = onCancel
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch camera.phase {
            case .preparing:
                ProgressView("Đang mở camera...")
                    .tint(.white)
                    .foregroundStyle(.white)

            case .permissionDenied:
                permissionDeniedView

            case .unavailable(let message):
                unavailableView(message: message)

            case .ready:
                if camera.isLivePreviewAvailable {
                    cameraPreview
                    controlsOverlay
                } else {
                    unavailableView(message: "Không thể khởi động camera.")
                }
            }
        }
        .task {
            await camera.prepare()
        }
        .onDisappear { camera.stop() }
        .sheet(isPresented: $showAlbum) {
            MediaAlbumPicker(
                onPick: { media in
                    showAlbum = false
                    onMediaCaptured(media)
                },
                onCancel: { showAlbum = false }
            )
        }
    }

    private var cameraPreview: some View {
        GeometryReader { geo in
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()
                .onAppear { previewSize = geo.size }
                .onChange(of: geo.size) { previewSize = $0 }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            camera.focus(at: value.location, in: previewSize)
                        }
                )
        }
    }

    private var controlsOverlay: some View {
        VStack {
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                Button {
                    camera.cycleFlash()
                } label: {
                    Image(systemName: camera.flashIconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .disabled(camera.cameraPosition == .front)
                .opacity(camera.cameraPosition == .front ? 0.35 : 1)
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.top, SplickTheme.Spacing.sm)

            Spacer()

            HStack(alignment: .center) {
                Button {
                    showAlbum = true
                } label: {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                }

                Spacer()

                Button {
                    Task {
                        if let image = await camera.capturePhoto() {
                            onMediaCaptured(.image(image))
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(.white, lineWidth: 4)
                            .frame(width: 76, height: 76)
                        Circle()
                            .fill(.white)
                            .frame(width: 62, height: 62)
                    }
                }
                .disabled(camera.isCapturing)
                .opacity(camera.isCapturing ? 0.6 : 1)

                Spacer()

                Button {
                    camera.toggleCamera()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.xl)
            .padding(.bottom, SplickTheme.Spacing.xl)
        }
    }

    private func unavailableView(message: String) -> some View {
        VStack(spacing: SplickTheme.Spacing.lg) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.7))

            Text(message)
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, SplickTheme.Spacing.xl)

            SplickButton("Chọn từ Album", style: .primary) {
                showAlbum = true
            }
            .padding(.horizontal, SplickTheme.Spacing.xl)

            SplickButton("Đóng", style: .secondary, action: onCancel)
                .padding(.horizontal, SplickTheme.Spacing.xl)
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.7))
            Text("Cần quyền Camera")
                .font(SplickTheme.Typography.title)
                .foregroundStyle(.white)
            Text("Bật quyền Camera trong Cài đặt để chụp ảnh và đăng bài.")
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, SplickTheme.Spacing.xl)

            SplickButton("Chọn từ Album", style: .primary) {
                showAlbum = true
            }
            .padding(.horizontal, SplickTheme.Spacing.xl)

            SplickButton("Đóng", style: .secondary, action: onCancel)
                .padding(.horizontal, SplickTheme.Spacing.xl)
        }
    }
}
