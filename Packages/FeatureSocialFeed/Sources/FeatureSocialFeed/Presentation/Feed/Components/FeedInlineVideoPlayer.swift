import SwiftUI
import AVFoundation
import Combine
import DesignSystem
import os.signpost

enum FeedVideoSpeed {
    static let options: [Float] = stride(from: Float(0), through: Float(2), by: Float(0.25)).map { $0 }

    static func label(for rate: Float) -> String {
        if rate == 0 { return "0×" }
        if rate.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f×", rate)
        }
        return String(format: "%.2g×", rate)
    }
}

/// Custom inline feed player: autoplay when visible, muted by default.
/// Timeline/speed live on post detail (`showsScrubber`). Inactive cells show poster only.
/// Tap the surface to pause/resume without opening a fullscreen video viewer.
struct FeedInlineVideoPlayer: View {
    let postId: UUID
    let url: URL
    let posterURL: URL?
    let durationSeconds: Int?
    var displayHeight: CGFloat = FeedMediaLayout.defaultHeight
    /// Feed hides the timeline; post detail / media viewer can show it.
    var showsScrubber: Bool = false
    /// Explicit feed autoplay target (avoids Equatable PostCard swallowing `@Published` updates).
    var isAutoplayTarget: Bool = false

    @Environment(\.feedVideoCoordinator) private var autoplayCoordinator
    @Environment(\.feedTabIsActive) private var feedTabIsActive
    @State private var isScrubbing = false
    @State private var scrubProgress: Double = 0
    @State private var showSpeedMenu = false
    /// Observe the pooled controller when this post is active.
    @StateObject private var controllerProxy = FeedVideoControllerProxy()
    /// Used when there is no feed autoplay coordinator (e.g. linked post overlay).
    @State private var standaloneController: FeedVideoPlaybackController?

    private let centerButtonSize: CGFloat = 88

    /// Post detail (scrubber) and overlays without a feed pool use a dedicated controller.
    private var usesStandalonePlayback: Bool {
        showsScrubber || autoplayCoordinator == nil
    }

    private var isAutoplayActive: Bool {
        if usesStandalonePlayback { return true }
        return feedTabIsActive && isAutoplayTarget
    }

    private var controller: FeedVideoPlaybackController? {
        controllerProxy.controller
    }

    private var sliderProgress: Binding<Double> {
        Binding(
            get: {
                guard let controller else { return 0 }
                return isScrubbing ? scrubProgress : controller.progress
            },
            set: { newValue in
                scrubProgress = newValue
                isScrubbing = true
            }
        )
    }

    var body: some View {
        ZStack {
            mediaLayer
                .contentShape(Rectangle())
                .onTapGesture { handleSurfaceTap() }

            if showSpeedMenu {
                Color.black.opacity(0.001)
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.12)) {
                            showSpeedMenu = false
                        }
                    }
            }

            // Autoplay / idle poster: no center transport.
            // After the user taps: show play/pause while paused or briefly while playing.
            if controller?.showsCenterTransport == true {
                centerPlaybackButton
            }

            controlsOverlay
        }
        .frame(height: displayHeight)
        .onChange(of: isAutoplayActive) { active in
            syncController(active: active)
        }
        .onAppear {
            syncController(active: isAutoplayActive)
        }
        .onChange(of: isAutoplayTarget) { target in
            syncController(active: feedTabIsActive && target)
        }
        .onDisappear {
            if usesStandalonePlayback {
                standaloneController?.tearDown()
                standaloneController = nil
            } else {
                // Soft leave — keep pooled AVPlayer warm; avoid PlayerRemoteXPC thrash on recycle.
                controller?.setAutoplayActive(false)
            }
            controllerProxy.detach()
        }
        .onChange(of: feedTabIsActive) { active in
            if usesStandalonePlayback {
                syncController(active: active)
            } else {
                syncController(active: active && isAutoplayTarget)
            }
        }
    }

    private func syncController(active: Bool) {
        if usesStandalonePlayback {
            syncStandaloneController(active: active)
            return
        }
        guard let autoplayCoordinator else {
            syncStandaloneController(active: active)
            return
        }
        if active {
            let pooled = autoplayCoordinator.acquireController(for: postId, url: url)
            let alreadyAttached = controllerProxy.controller === pooled
            controllerProxy.attach(pooled)
            pooled.setAutoplayActive(true)
            if !alreadyAttached {
                FeedSignposts.videoPlayerAcquire(postId: postId)
            }
        } else {
            controller?.setAutoplayActive(false)
            // Keep poster-only for inactive cells; release pool slot on clearPost/suspend.
            if controllerProxy.controller != nil, !autoplayCoordinator.activePostIds.contains(postId) {
                // Detach observation but leave pool entry for LRU warm reuse until evicted.
                controllerProxy.detach()
            }
        }
    }

    private func syncStandaloneController(active: Bool) {
        guard active else {
            standaloneController?.setAutoplayActive(false)
            return
        }
        let owned = ensureStandaloneController()
        controllerProxy.attach(owned)
        owned.setAutoplayActive(true)
        FeedSignposts.videoPlayerAcquire(postId: postId)
    }

    private func ensureStandaloneController() -> FeedVideoPlaybackController {
        if let standaloneController { return standaloneController }
        let created = FeedVideoPlaybackController(url: url)
        standaloneController = created
        return created
    }

    @ViewBuilder
    private var mediaLayer: some View {
        ZStack {
            FeedVideoPosterView(
                posterURL: posterURL,
                videoURL: url,
                displayHeight: displayHeight
            )

            // Keep the poster underneath until the item is ready — AVPlayerLayer is black before decode.
            if let controller, controller.showsVideoSurface {
                FeedVideoPlayerLayerView(player: controller.player)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var centerPlaybackButton: some View {
        Button {
            handleSurfaceTap()
        } label: {
            Circle()
                .fill(.black.opacity(0.5))
                .frame(width: centerButtonSize, height: centerButtonSize)
                .overlay {
                    Image(systemName: centerIconName)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: centerIconName == "play.fill" ? 3 : 0)
                }
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
    }

    private func handleSurfaceTap() {
        if let controller {
            controller.togglePlaybackFromCenter()
            return
        }
        // Inactive cell / first attach: promote and let autoplay start playback.
        if usesStandalonePlayback {
            syncStandaloneController(active: true)
        } else if let autoplayCoordinator {
            autoplayCoordinator.updateVisibility(postId: postId, ratio: 1)
            syncController(active: true)
        } else {
            syncStandaloneController(active: true)
        }
        controllerProxy.controller?.revealTransportAfterUserTap()
    }

    private var centerIconName: String {
        if let controller, controller.isPlaying, controller.showsCenterTransport {
            return "pause.fill"
        }
        return "play.fill"
    }

    private var controlsOverlay: some View {
        VStack(spacing: 0) {
            HStack {
                muteButton
                Spacer()
                if controller?.showsVideoSurface != true, let durationSeconds {
                    durationBadge(seconds: durationSeconds)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)

            Spacer()

            if showsScrubber, controller != nil {
                transportRow
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.65)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }

    private var muteButton: some View {
        Button {
            controller?.toggleMute()
        } label: {
            Image(systemName: (controller?.isMuted ?? true) ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.black.opacity(0.45), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(controller == nil)
        .opacity(controller == nil ? 0 : 1)
    }

    private var transportRow: some View {
        HStack(spacing: 8) {
            Text(controller?.elapsedLabel ?? "0:00")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 34, alignment: .leading)
                .lineLimit(1)

            Slider(
                value: sliderProgress,
                in: 0...1,
                onEditingChanged: { editing in
                    if editing {
                        isScrubbing = true
                    } else {
                        controller?.seek(toFraction: scrubProgress)
                        isScrubbing = false
                    }
                }
            )
            .tint(.white)

            speedControl
        }
    }

    private var speedControl: some View {
        speedButton
            .overlay(alignment: .top) {
                if showSpeedMenu {
                    compactSpeedPopover
                        .offset(y: -84)
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
                        .allowsHitTesting(true)
                }
            }
    }

    private var speedButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                showSpeedMenu.toggle()
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.system(size: 11, weight: .semibold))
                Text(FeedVideoSpeed.label(for: controller?.playbackRate ?? 1))
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.white.opacity(0.22), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var compactSpeedPopover: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(FeedVideoSpeed.options, id: \.self) { rate in
                    Button {
                        controller?.setPlaybackRate(rate)
                        withAnimation(.easeOut(duration: 0.12)) {
                            showSpeedMenu = false
                        }
                    } label: {
                        Text(FeedVideoSpeed.label(for: rate))
                            .font(.system(
                                size: 9,
                                weight: (controller?.playbackRate ?? 1) == rate ? .bold : .medium
                            ))
                            .foregroundStyle(
                                (controller?.playbackRate ?? 1) == rate ? .white : .white.opacity(0.75)
                            )
                            .frame(width: 38, height: 14)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 42, height: 78)
        .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.18), lineWidth: 0.5)
        )
    }

    private func durationBadge(seconds: Int) -> some View {
        let clamped = min(seconds, 30)
        return Text(String(format: "0:%02d", clamped))
            .font(SplickTheme.Typography.captionBold)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.55), in: Capsule())
    }
}

// MARK: - Controller proxy (observe pooled controller without @StateObject)

@MainActor
final class FeedVideoControllerProxy: ObservableObject {
    @Published private(set) var controller: FeedVideoPlaybackController?
    private var cancellable: AnyCancellable?

    func attach(_ controller: FeedVideoPlaybackController) {
        guard self.controller !== controller else { return }
        self.controller = controller
        cancellable = controller.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func detach() {
        cancellable = nil
        controller = nil
    }
}

@MainActor
final class FeedVideoPlaybackController: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var showsCenterTransport = false
    @Published private(set) var isMuted = true
    @Published private(set) var progress: Double = 0
    @Published private(set) var playbackRate: Float = 1
    @Published private(set) var showsVideoSurface = false

    let player: AVPlayer

    var elapsedLabel: String {
        let seconds = Int((progress * duration).rounded())
        return formatTime(seconds)
    }

    private var playerItem: AVPlayerItem
    private var duration: Double = 0
    private var endObserver: NSObjectProtocol?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var hideTransportTask: Task<Void, Never>?
    private var userPaused = false
    private var autoplayActive = false
    private var pendingPlay = false
    private var tornDown = false

    init(url: URL) {
        playerItem = Self.makeItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = true
        if #available(iOS 16.0, *) {
            player.audiovisualBackgroundPlaybackPolicy = .pauses
        }
        Self.configureAudioSession()
        player.actionAtItemEnd = .pause
        player.isMuted = true
        bindItemObservers()
        setupTimeObserver()
        FeedSignposts.videoPlayerCreate()
    }

    func replaceURL(_ url: URL) {
        pause(userInitiated: false)
        unbindItemObservers()
        playerItem = Self.makeItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        progress = 0
        duration = 0
        showsVideoSurface = false
        bindItemObservers()
    }

    func tearDown() {
        guard !tornDown else { return }
        tornDown = true
        hideTransportTask?.cancel()
        pause(userInitiated: false)
        unbindItemObservers()
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        player.replaceCurrentItem(with: nil)
        FeedSignposts.videoPlayerRelease()
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        statusObserver?.invalidate()
    }

    func setAutoplayActive(_ active: Bool) {
        guard autoplayActive != active else {
            // Already in the desired mode — avoid re-entering play()/pause() which
            // republish @Published fields and can feedback into SwiftUI layout.
            if active, !userPaused, !isPlaying {
                play(userInitiated: false)
            }
            return
        }
        autoplayActive = active
        if !active {
            pause(userInitiated: false)
            return
        }
        if !userPaused {
            play(userInitiated: false)
        }
    }

    func togglePlaybackFromCenter() {
        if isPlaying {
            pause(userInitiated: true)
            flashCenterTransport(iconIsPause: true)
        } else {
            play(userInitiated: true)
            revealTransportAfterUserTap()
        }
    }

    /// Brief center transport after a user tap (autoplay itself stays chrome-free).
    func revealTransportAfterUserTap() {
        showsCenterTransport = true
        hideTransportTask?.cancel()
        hideTransportTask = Task {
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled else { return }
            if userPaused || !isPlaying {
                showsCenterTransport = true
            } else {
                showsCenterTransport = false
            }
        }
    }

    func toggleMute() {
        isMuted.toggle()
        player.isMuted = isMuted
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        if rate <= 0 {
            pause(userInitiated: true)
            return
        }
        if isPlaying {
            player.rate = rate
        } else if userPaused == false || autoplayActive {
            play(userInitiated: false)
        }
    }

    func seek(toFraction fraction: Double) {
        let clamped = min(max(fraction, 0), 1)
        guard duration > 0 else { return }
        let seconds = clamped * duration
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        progress = clamped
    }

    func play(userInitiated: Bool) {
        if userInitiated {
            userPaused = false
        }
        pendingPlay = true

        if playerItem.status == .readyToPlay {
            beginPlayback()
        } else {
            // Do not flip showsVideoSurface yet — poster stays visible until ready.
            player.play()
        }
    }

    func pause(userInitiated: Bool) {
        pendingPlay = false
        if userInitiated {
            userPaused = true
        }
        player.pause()
        isPlaying = false
        hideTransportTask?.cancel()
        if userInitiated {
            showsCenterTransport = true
        } else {
            showsCenterTransport = false
        }
    }

    private func beginPlayback() {
        pendingPlay = false
        guard playbackRate > 0 else {
            pause(userInitiated: true)
            return
        }

        if !showsVideoSurface {
            showsVideoSurface = true
        }
        if player.rate == 0 {
            player.play()
        }
        if abs(player.rate - playbackRate) > 0.001 {
            player.rate = playbackRate
        }
        if !isPlaying {
            isPlaying = true
        }
    }

    private func handlePlaybackEnded() {
        player.seek(to: .zero)
        progress = 0
        pause(userInitiated: false)
        userPaused = false
        if autoplayActive {
            play(userInitiated: false)
        } else {
            showsCenterTransport = true
        }
    }

    private func flashCenterTransport(iconIsPause: Bool) {
        showsCenterTransport = true
        hideTransportTask?.cancel()
        hideTransportTask = Task {
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled else { return }
            if iconIsPause {
                showsCenterTransport = true
            } else {
                showsCenterTransport = false
            }
        }
    }

    private static func makeItem(url: URL) -> AVPlayerItem {
        let item = AVPlayerItem(url: url)
        item.preferredMaximumResolution = CGSize(
            width: FeedMediaLayout.decodeMaxPixelSide,
            height: FeedMediaLayout.decodeMaxPixelSide
        )
        item.preferredForwardBufferDuration = 2
        return item
    }

    private func bindItemObservers() {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.handlePlaybackEnded()
        }

        statusObserver = playerItem.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            guard item.status == .readyToPlay else { return }
            Task { @MainActor in
                guard let self, self.pendingPlay else { return }
                self.beginPlayback()
            }
        }
    }

    private func unbindItemObservers() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        statusObserver?.invalidate()
        statusObserver = nil
    }

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.12, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let itemDuration = self.playerItem.duration.seconds
            guard itemDuration.isFinite, itemDuration > 0 else { return }
            let next = min(max(time.seconds / itemDuration, 0), 1)
            self.duration = itemDuration
            // Skip sub-percent noise so scrubber publishes do not thrash SwiftUI mid-layout.
            guard abs(next - self.progress) >= 0.01 || next <= 0.001 || next >= 0.999 else { return }
            self.progress = next
        }
    }

    private static func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - AVPlayerLayer host

private struct FeedVideoPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> FeedPlayerUIView {
        let view = FeedPlayerUIView()
        view.configure(player: player)
        return view
    }

    func updateUIView(_ uiView: FeedPlayerUIView, context: Context) {
        uiView.configure(player: player)
    }
}

private final class FeedPlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    func configure(player: AVPlayer) {
        playerLayer.player = player
    }
}
