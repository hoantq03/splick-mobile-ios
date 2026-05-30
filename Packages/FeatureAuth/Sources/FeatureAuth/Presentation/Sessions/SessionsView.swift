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
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
                    HStack {
                        Text(session.displayDevice)
                            .font(SplickTheme.Typography.body)
                        Spacer()
                        if session.isCurrent {
                            Text("This device")
                                .font(SplickTheme.Typography.caption)
                                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                        } else {
                            Button("Sign out") {
                                Task { await viewModel.revoke(session: session) }
                            }
                            .font(SplickTheme.Typography.caption)
                        }
                    }

                    if let deviceInfo = session.deviceInfo, deviceInfo != session.displayDevice {
                        Text(deviceInfo)
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                    }

                    if let location = sessionLocationText(session) {
                        Label(location, systemImage: "location")
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                    }

                    Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }
                .padding(.vertical, SplickTheme.Spacing.xs)
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
                SplickSpinner(size: .medium)
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private func sessionLocationText(_ session: UserSession) -> String? {
        if let loginLocation = session.loginLocation, !loginLocation.isEmpty {
            if let loginIp = session.loginIp, !loginIp.isEmpty {
                return "\(loginLocation) · \(loginIp)"
            }
            return loginLocation
        }
        if let loginIp = session.loginIp, !loginIp.isEmpty {
            return loginIp
        }
        return nil
    }
}
