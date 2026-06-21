import SwiftUI
import DesignSystem
import Localization
import SplickDomain

public struct SessionsView: View {
    @StateObject private var viewModel: SessionsViewModel
    @EnvironmentObject private var languageService: LanguageService

    public init(viewModel: @autoclosure @escaping () -> SessionsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                Text(languageService.text(.sessionsSubtitle))
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

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

                if viewModel.sessions.count > 1 {
                    SplickButton(languageService.text(.sessionsSignOutAll), style: .destructive) {
                        Task { await viewModel.revokeAll() }
                    }
                }
            }
            .padding(SplickTheme.Spacing.lg)
        }
        .background(SplickTheme.Colors.background)
        .navigationTitle(languageService.text(.sessionsTitle))
        .navigationBarTitleDisplayMode(.inline)
        .onFirstAppear {
            Task { await viewModel.load() }
        }
        .refreshable { await viewModel.load(isPullToRefresh: true) }
    }

    private func sessionCard(_ session: UserSession) -> some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
            HStack(alignment: .top, spacing: SplickTheme.Spacing.md) {
                deviceIcon(for: session)

                VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxs) {
                    HStack(alignment: .firstTextBaseline, spacing: SplickTheme.Spacing.xs) {
                        Text(session.displayTitle)
                            .font(SplickTheme.Typography.headline)
                            .foregroundStyle(SplickTheme.Colors.textPrimary)
                            .lineLimit(2)

                        Spacer(minLength: SplickTheme.Spacing.xs)

                        if session.isCurrent {
                            currentDeviceBadge
                        }
                    }

                    if let platform = session.displayPlatform {
                        Text(platform)
                            .font(SplickTheme.Typography.callout)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
                infoRow(
                    icon: "location.fill",
                    tint: SplickTheme.Colors.info,
                    title: languageService.text(.sessionsLocation),
                    value: session.displayLocationLine ?? languageService.text(.sessionsUnknownLocation),
                    isPlaceholder: session.displayLocationLine == nil
                )

                infoRow(
                    icon: "clock.fill",
                    tint: SplickTheme.Colors.textSecondary,
                    title: languageService.text(.sessionsSignedIn),
                    value: session.createdAt.formatted(date: .abbreviated, time: .shortened),
                    isPlaceholder: false
                )

                infoRow(
                    icon: "hourglass",
                    tint: SplickTheme.Colors.warning,
                    title: languageService.text(.sessionsExpires),
                    value: session.expiresAt.formatted(date: .abbreviated, time: .shortened),
                    isPlaceholder: false
                )
            }
            .padding(.leading, SplickTheme.Spacing.xl + SplickTheme.Spacing.md)

            if !session.isCurrent {
                HStack {
                    Spacer()
                    Button {
                        Task { await viewModel.revoke(session: session) }
                    } label: {
                        Text(languageService.text(.sessionsSignOut))
                            .font(SplickTheme.Typography.captionBold)
                            .foregroundStyle(SplickTheme.Colors.error)
                            .padding(.horizontal, SplickTheme.Spacing.md)
                            .padding(.vertical, SplickTheme.Spacing.xs)
                            .background(SplickTheme.Colors.error.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(SplickTheme.Spacing.md)
        .background(SplickTheme.Colors.cardBackground)
        .overlay {
            if session.isCurrent {
                RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.control, style: .continuous)
                    .strokeBorder(SplickTheme.Colors.primaryGradient, lineWidth: 1.5)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.control, style: .continuous))
    }

    private func deviceIcon(for session: UserSession) -> some View {
        ZStack {
            Circle()
                .fill(SplickTheme.Colors.primaryGradientStart.opacity(0.14))
                .frame(width: 48, height: 48)

            Image(systemName: session.deviceKind.systemImageName)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.primaryGradient)
                .symbolRenderingMode(.hierarchical)
        }
        .accessibilityHidden(true)
    }

    private var currentDeviceBadge: some View {
        Text(languageService.text(.sessionsThisDevice))
            .font(SplickTheme.Typography.captionBold)
            .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
            .padding(.horizontal, SplickTheme.Spacing.sm)
            .padding(.vertical, 4)
            .background(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
            .clipShape(Capsule())
    }

    private func infoRow(
        icon: String,
        tint: Color,
        title: String,
        value: String,
        isPlaceholder: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: SplickTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 16, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
                Text(value)
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(isPlaceholder ? SplickTheme.Colors.textTertiary : SplickTheme.Colors.textSecondary)
            }
        }
    }
}
