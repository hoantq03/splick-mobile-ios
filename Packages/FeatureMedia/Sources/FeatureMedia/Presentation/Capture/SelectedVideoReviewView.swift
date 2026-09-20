import AVKit
import Localization
import SwiftUI

/// Full-screen playback for a video already attached to a compose draft.
public struct SelectedVideoReviewView: View {
    let url: URL
    let onDismiss: () -> Void
    @EnvironmentObject private var languageService: LanguageService
    @State private var player: AVPlayer

    public init(url: URL, onDismiss: @escaping () -> Void) {
        self.url = url
        self.onDismiss = onDismiss
        _player = State(initialValue: AVPlayer(url: url))
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            VideoPlayer(player: player)
                .ignoresSafeArea()
                .onAppear { player.play() }
                .onDisappear {
                    player.pause()
                    player.replaceCurrentItem(with: nil)
                }
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.45))
                    .padding(16)
            }
            .accessibilityLabel(languageService.text(.commonClose))
        }
        .background(Color.black.ignoresSafeArea())
    }
}
