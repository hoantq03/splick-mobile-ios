import SwiftUI
import WidgetKit
import DesignSystem
import Localization
import SplickWidgetKit

public struct WidgetSettingsView: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.scenePhase) private var scenePhase

    @State private var installedKinds: Set<String> = []
    @State private var selectedWidget: HomeScreenWidget?

    public init() {}

    public var body: some View {
        List {
            Section {
                ForEach(HomeScreenWidget.allCases) { widget in
                    Button {
                        WidgetCenter.shared.reloadTimelines(ofKind: widget.kind)
                        selectedWidget = widget
                    } label: {
                        HStack(alignment: .center, spacing: SplickTheme.Spacing.md) {
                            HomeScreenWidgetPreview(
                                widget: widget,
                                title: languageService.text(widget.titleKey)
                            )
                            .frame(width: 118, height: 118)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(languageService.text(widget.titleKey))
                                    .font(SplickTheme.Typography.headline)
                                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Text(languageService.text(widget.descriptionKey))
                                    .font(SplickTheme.Typography.caption)
                                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(languageService.text(widget.sizesKey))
                                    .font(SplickTheme.Typography.caption)
                                    .foregroundStyle(SplickTheme.Colors.textTertiary)
                                if installedKinds.contains(widget.kind) {
                                    Text(languageService.text(.profileWidgetAdded))
                                        .font(SplickTheme.Typography.caption)
                                        .foregroundStyle(SplickTheme.Colors.success)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text(languageService.text(.profileWidgetHint))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(languageService.text(.profileWidget))
        .navigationBarTitleDisplayMode(.inline)
        .task { refreshInstalledKinds() }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                refreshInstalledKinds()
            }
        }
        .sheet(item: $selectedWidget) { widget in
            WidgetPreviewSheet(
                widget: widget,
                isInstalled: installedKinds.contains(widget.kind)
            )
            .environmentObject(languageService)
        }
    }

    private func refreshInstalledKinds() {
        WidgetCenter.shared.getCurrentConfigurations { result in
            let kinds = Set((try? result.get())?.map(\.kind) ?? [])
            DispatchQueue.main.async {
                installedKinds = kinds
            }
        }
    }
}

private struct WidgetPreviewSheet: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss

    let widget: HomeScreenWidget
    let isInstalled: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SplickTheme.Spacing.lg) {
                    HomeScreenWidgetPreview(
                        widget: widget,
                        title: languageService.text(widget.titleKey)
                    )
                    .frame(width: 168, height: 168)
                    .padding(.top, SplickTheme.Spacing.md)

                    VStack(spacing: SplickTheme.Spacing.xs) {
                        Text(languageService.text(widget.titleKey))
                            .font(SplickTheme.Typography.title)
                            .multilineTextAlignment(.center)
                        Text(languageService.text(widget.descriptionKey))
                            .font(SplickTheme.Typography.callout)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                        Text(languageService.text(widget.sizesKey))
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textTertiary)
                    }
                    .padding(.horizontal, SplickTheme.Spacing.lg)

                    if isInstalled {
                        Text(languageService.text(.profileWidgetAdded))
                            .font(SplickTheme.Typography.captionBold)
                            .foregroundStyle(SplickTheme.Colors.success)
                    }

                    Text(languageService.text(.profileWidgetAddSteps))
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, SplickTheme.Spacing.lg)

                    Button(languageService.text(.profileWidgetAdd)) {
                        WidgetCenter.shared.reloadTimelines(ofKind: widget.kind)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(SplickTheme.Colors.primaryGradientStart)
                    .padding(.bottom, SplickTheme.Spacing.xl)
                }
                .frame(maxWidth: .infinity)
            }
            .background(SplickTheme.Colors.background)
            .navigationTitle(languageService.text(.profileWidget))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonDone)) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private extension HomeScreenWidget {
    var titleKey: L10nKey {
        switch self {
        case .expenseSummary: return .profileWidgetExpenseSummary
        case .unreadMessages: return .profileWidgetUnreadMessages
        case .latestFriendPhoto: return .profileWidgetLatestPhoto
        case .friendStreak: return .profileWidgetStreak
        case .quickCapture: return .profileWidgetQuickCapture
        case .friendRequest: return .profileWidgetFriendRequest
        case .groupExpense: return .profileWidgetGroupExpense
        }
    }

    var descriptionKey: L10nKey {
        switch self {
        case .expenseSummary: return .profileWidgetExpenseSummaryDesc
        case .unreadMessages: return .profileWidgetUnreadMessagesDesc
        case .latestFriendPhoto: return .profileWidgetLatestPhotoDesc
        case .friendStreak: return .profileWidgetStreakDesc
        case .quickCapture: return .profileWidgetQuickCaptureDesc
        case .friendRequest: return .profileWidgetFriendRequestDesc
        case .groupExpense: return .profileWidgetGroupExpenseDesc
        }
    }

    var sizesKey: L10nKey {
        switch self {
        case .expenseSummary: return .profileWidgetExpenseSummarySizes
        case .unreadMessages: return .profileWidgetUnreadMessagesSizes
        case .latestFriendPhoto: return .profileWidgetLatestPhotoSizes
        case .friendStreak: return .profileWidgetStreakSizes
        case .quickCapture: return .profileWidgetQuickCaptureSizes
        case .friendRequest: return .profileWidgetFriendRequestSizes
        case .groupExpense: return .profileWidgetGroupExpenseSizes
        }
    }
}
