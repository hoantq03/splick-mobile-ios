import SwiftUI
import DesignSystem
import Localization
import SplickDomain

public struct NearbyRadarSheet: View {
    @EnvironmentObject private var languageService: LanguageService
    let permissionNeeded: Bool
    let users: [UserSearchResult]
    let loading: Bool
    let selectionMode: Bool
    let selectedUserIds: Set<UUID>
    var onClose: () -> Void
    var onRequestLocation: () -> Void
    var onOpenUser: (UserSearchResult) -> Void
    var actionForResult: (UserSearchResult) -> (() -> Void)?
    var onToggleSelection: ((UserSearchResult) -> Void)?
    var onConfirmSelection: (() -> Void)?

    public init(
        permissionNeeded: Bool,
        users: [UserSearchResult],
        loading: Bool,
        selectionMode: Bool = false,
        selectedUserIds: Set<UUID> = [],
        onClose: @escaping () -> Void,
        onRequestLocation: @escaping () -> Void,
        onOpenUser: @escaping (UserSearchResult) -> Void,
        actionForResult: @escaping (UserSearchResult) -> (() -> Void)?,
        onToggleSelection: ((UserSearchResult) -> Void)? = nil,
        onConfirmSelection: (() -> Void)? = nil
    ) {
        self.permissionNeeded = permissionNeeded
        self.users = users
        self.loading = loading
        self.selectionMode = selectionMode
        self.selectedUserIds = selectedUserIds
        self.onClose = onClose
        self.onRequestLocation = onRequestLocation
        self.onOpenUser = onOpenUser
        self.actionForResult = actionForResult
        self.onToggleSelection = onToggleSelection
        self.onConfirmSelection = onConfirmSelection
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: SplickTheme.Spacing.sm) {
                    Text(languageService.text(.friendsNearbyScanning))
                        .font(SplickTheme.Typography.body)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)

                    NearbyRadarSweepView()
                        .frame(width: 180, height: 180)
                        .padding(.vertical, SplickTheme.Spacing.xs)

                    Text(languageService.text(.friendsNearbySessionHint))
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)

                    if permissionNeeded {
                        SplickButton(languageService.text(.friendsNearbyPermission), style: .primary) {
                            onRequestLocation()
                        }
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
                .padding(.bottom, SplickTheme.Spacing.sm)

                if !permissionNeeded {
                    ScrollView {
                        LazyVStack(spacing: SplickTheme.Spacing.xs) {
                            if users.isEmpty {
                                Text(
                                    languageService.text(
                                        loading ? .friendsNearbyScanning : .friendsNearbyEmpty
                                    )
                                )
                                .font(SplickTheme.Typography.body)
                                .foregroundStyle(SplickTheme.Colors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, SplickTheme.Spacing.md)
                            } else {
                                ForEach(users) { result in
                                    nearbyUserRow(result)
                                }
                            }
                        }
                        .padding(.horizontal, SplickTheme.Spacing.md)
                        .padding(.bottom, SplickTheme.Spacing.md)
                    }
                } else {
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SplickTheme.Colors.background)
            .navigationTitle(languageService.text(.friendsNearbyTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonClose), action: onClose)
                }
                if selectionMode, let onConfirmSelection {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(languageService.text(.commonDone), action: onConfirmSelection)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func nearbyUserRow(_ result: UserSearchResult) -> some View {
        let subtitle = result.distanceMeters.map {
            languageService.format(.friendsNearbyDistanceMeters, $0)
        }
        if selectionMode {
            HStack(spacing: SplickTheme.Spacing.xs) {
                FriendRowView(
                    user: result.user,
                    friendStatus: result.friendStatus,
                    subtitle: subtitle,
                    compact: true,
                    onProfileTap: { onToggleSelection?(result) },
                    onAddFriend: actionForResult(result)
                )
                Button {
                    onToggleSelection?(result)
                } label: {
                    Image(systemName: selectedUserIds.contains(result.user.id)
                          ? "checkmark.circle.fill"
                          : "circle")
                        .font(.title3)
                        .foregroundStyle(
                            selectedUserIds.contains(result.user.id)
                                ? SplickTheme.Colors.primaryGradientStart
                                : SplickTheme.Colors.textTertiary
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, SplickTheme.Spacing.sm)
            }
        } else {
            FriendRowView(
                user: result.user,
                friendStatus: result.friendStatus,
                subtitle: subtitle,
                onProfileTap: { onOpenUser(result) },
                onAddFriend: actionForResult(result)
            )
        }
    }
}

struct NearbyRadarSweepView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let angle = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 2.4) / 2.4 * 360
            Canvas { context, size in
                let radius = min(size.width, size.height) / 2
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let color = SplickTheme.Colors.primaryGradientStart
                for i in 1...3 {
                    var ring = Path()
                    ring.addEllipse(in: CGRect(
                        x: center.x - radius * CGFloat(i) / 3,
                        y: center.y - radius * CGFloat(i) / 3,
                        width: radius * 2 * CGFloat(i) / 3,
                        height: radius * 2 * CGFloat(i) / 3
                    ))
                    context.stroke(ring, with: .color(color.opacity(0.35)), lineWidth: 1.5)
                }
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)),
                    with: .color(color)
                )
                var sweepContext = context
                sweepContext.translateBy(x: center.x, y: center.y)
                sweepContext.rotate(by: .degrees(angle))
                var sweep = Path()
                sweep.move(to: .zero)
                sweep.addArc(
                    center: .zero,
                    radius: radius,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(0),
                    clockwise: false
                )
                sweep.closeSubpath()
                sweepContext.fill(sweep, with: .color(color.opacity(0.28)))
            }
        }
    }
}
