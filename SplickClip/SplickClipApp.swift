//
//  SplickClipApp.swift
//  SplickClip
//

import SwiftUI

@main
struct SplickClipApp: App {
    @StateObject private var viewModel = ClipInviteViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                // Primary: iOS routes NFC NDEF URL via NSUserActivity (background tag reading)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    viewModel.handleInviteURL(url)
                }
                // Fallback: simulator testing via Safari / xcrun simctl openurl
                .onOpenURL { url in
                    viewModel.handleInviteURL(url)
                }
        }
    }
}
