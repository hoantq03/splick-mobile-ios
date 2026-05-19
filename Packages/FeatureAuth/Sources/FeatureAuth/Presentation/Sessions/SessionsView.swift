import SwiftUI
import DesignSystem
import SplickDomain

public struct SessionsView: View {
    @StateObject private var viewModel: SessionsViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: @autoclosure @escaping () -> SessionsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    public var body: some View {
        List {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.error)
            }

            ForEach(viewModel.sessions) { session in
                HStack {
                    VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
                        Text(session.deviceInfo ?? "Unknown device")
                            .font(SplickTheme.Typography.body)
                        Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                        if session.isCurrent {
                            Text("This device")
                                .font(SplickTheme.Typography.caption)
                                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                        }
                    }
                    Spacer()
                    if !session.isCurrent {
                        Button("Sign out") {
                            Task { await viewModel.revoke(session: session) }
                        }
                        .font(SplickTheme.Typography.caption)
                    }
                }
            }
        }
        .navigationTitle("Devices")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("Sign out all") {
                    Task { await viewModel.revokeAll() }
                }
            }
        }
        .overlay {
            if viewModel.loadingState == .loading && viewModel.sessions.isEmpty {
                ProgressView()
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}
