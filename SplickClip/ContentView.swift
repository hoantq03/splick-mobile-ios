//
//  ContentView.swift
//  SplickClip
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ProfileCardView()
    }
}

#Preview {
    ContentView()
        .environmentObject(ClipInviteViewModel())
}
