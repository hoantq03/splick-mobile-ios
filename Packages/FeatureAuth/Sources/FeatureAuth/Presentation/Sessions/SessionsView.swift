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
        ScrollView {
            VStack(spacing: SplickTheme.Spacing.lg) {
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if viewModel.sessions.isEmpty, viewModel.loadingState == .loading {
                    SplickSpinner(size: .medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SplickTheme.Spacing.xl)
                } else {
                    VStack(spacing: SplickTheme.Spacing.sm) {
                        ForEach(viewModel.sessions) { session in
                            sessionCard(session)
                        }
                    }
                }

                if !viewModel.sessions.isEmpty {
                    SplickButton("Sign out all", style: .destructive) {
                        Task { await viewModel.revokeAll() }
                    }
                }
            }
            .padding(SplickTheme.Spacing.lg)
        }
        .background(SplickTheme.Colors.background)
        .navigationTitle("Devices")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private func sessionCard(_ session: UserSession) -> some View {
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
                    .foregroundStyle(SplickTheme.Colors.error)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SplickTheme.Spacing.md)
        .background(SplickTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.control, style: .continuous))
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
