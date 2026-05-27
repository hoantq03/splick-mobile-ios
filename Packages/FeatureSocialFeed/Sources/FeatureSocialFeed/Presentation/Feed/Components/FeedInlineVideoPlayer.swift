import SwiftUI
import AVFoundation
import Combine
import DesignSystem

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

/// Custom inline feed player: autoplay when visible, muted by default, scrubber + speed menu.
struct FeedInlineVideoPlayer: View {
    let postId: UUID
    let url: URL
    let posterURL: URL?
    let durationSeconds: Int?

    @Environment(\.feedVideoCoordinator) private var autoplayCoordinator
    @StateObject private var controller: FeedVideoPlaybackController
    @State private var isScrubbing = false
    @State private var scrubProgress: Double = 0
    @State private var showSpeedMenu = false

    private let centerButtonSize: CGFloat = 88

    init(postId: UUID, url: URL, posterURL: URL?, durationSeconds: Int?) {
        self.postId = postId
        self.url = url
        self.posterURL = posterURL
        self.durationSeconds = durationSeconds
        _controller = StateObject(wrappedValue: FeedVideoPlaybackController(url: url))
    }

    private var isAutoplayActive: Bool {
        autoplayCoordinator?.activePostId == postId
    }

    private var sliderProgress: Binding<Double> {
        Binding(
            get: { isScrubbing ? scrubProgress : controller.progress },
            set: { newValue in
                scrubProgress = newValue
                isScrubbing = true
            }
        )
    }

    var body: some View {
        ZStack {
            mediaLayer

            if showSpeedMenu {
                Color.black.opacity(0.001)
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.12)) {
                            showSpeedMenu = false
                        }
                    }
            }

            if !controller.isPlaying || controller.showsCenterTransport {
                centerPlaybackButton
            }

            controlsOverlay
        }
        .frame(height: 350)
        .background(FeedVideoVisibilityReporter(postId: postId))
        .onChange(of: isAutoplayActive) { active in
            controller.setAutoplayActive(active)
        }
        .onAppear {
            autoplayCoordinator?.updateVisibility(postId: postId, ratio: 0.85)
            controller.setAutoplayActive(isAutoplayActive)
        }
        .onDisappear {
            autoplayCoordinator?.clearPost(postId)
            controller.setAutoplayActive(false)
        }
    }

    @ViewBuilder
    private var mediaLayer: some View {
        Group {
            if controller.showsVideoSurface {
                FeedVideoPlayerLayerView(player: controller.player)
            } else if let posterURL {
                RemoteImage(url: posterURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Color.black.opacity(0.88)
                    }
                }
            } else {
                Color.black.opacity(0.88)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var centerPlaybackButton: some View {
        Button {
            controller.togglePlaybackFromCenter()
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

    private var centerIconName: String {
        if controller.isPlaying, controller.showsCenterTransport {
            return "pause.fill"
        }
        return "play.fill"
    }

    private var controlsOverlay: some View {
        VStack(spacing: 0) {
            HStack {
                muteButton
                Spacer()
                if !controller.showsVideoSurface, let durationSeconds {
                    durationBadge(seconds: durationSeconds)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)

            Spacer()

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

    private var muteButton: some View {
        Button {
            controller.toggleMute()
        } label: {
            Image(systemName: controller.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.black.opacity(0.45), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var transportRow: some View {
        HStack(spacing: 8) {
            Text(controller.elapsedLabel)
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
                        controller.seek(toFraction: scrubProgress)
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
                Text(FeedVideoSpeed.label(for: controller.playbackRate))
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
                        controller.setPlaybackRate(rate)
                        withAnimation(.easeOut(duration: 0.12)) {
                            showSpeedMenu = false
                        }
                    } label: {
                        Text(FeedVideoSpeed.label(for: rate))
                            .font(.system(size: 9, weight: controller.playbackRate == rate ? .bold : .medium))
                            .foregroundStyle(
                                controller.playbackRate == rate ? .white : .white.opacity(0.75)
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

    private let playerItem: AVPlayerItem
    private var duration: Double = 0
    private var endObserver: NSObjectProtocol?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var hideTransportTask: Task<Void, Never>?
    private var userPaused = false
    private var autoplayActive = false
    private var pendingPlay = false

    init(url: URL) {
        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        Self.configureAudioSession()
        player.actionAtItemEnd = .pause
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = true

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.handlePlaybackEnded()
        }

        statusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self, item.status == .readyToPlay, self.pendingPlay else { return }
            self.beginPlayback()
        }

        setupTimeObserver()
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        statusObserver?.invalidate()
    }

    func setAutoplayActive(_ active: Bool) {
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
        showsVideoSurface = true
        pendingPlay = true

        if playerItem.status == .readyToPlay {
            beginPlayback()
        } else {
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

        if player.rate == 0 {
            player.play()
        }
        player.rate = playbackRate
        isPlaying = true
        showsCenterTransport = false
    }

    private func handlePlaybackEnded() {
        player.seek(to: .zero)
        progress = 0
        pause(userInitiated: false)
        userPaused = false
        showsCenterTransport = true
        if autoplayActive {
            play(userInitiated: false)
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

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.12, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let itemDuration = self.playerItem.duration.seconds
            guard itemDuration.isFinite, itemDuration > 0 else { return }
            self.duration = itemDuration
            self.progress = min(max(time.seconds / itemDuration, 0), 1)
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
