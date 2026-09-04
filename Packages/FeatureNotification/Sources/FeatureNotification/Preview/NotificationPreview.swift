import Foundation
import SwiftUI
import Localization
import Storage
import SplickDomain

#if DEBUG

final class MockFetchNotificationsUseCase: FetchNotificationsUseCaseProtocol, Sendable {
    func execute(page: Int, category: NotificationListCategory) async throws -> [AppNotification] {
        try await Task.sleep(for: .milliseconds(500))
        return PreviewData.sampleNotifications
    }
}

final class MockMarkNotificationReadUseCase: MarkNotificationReadUseCaseProtocol, Sendable {
    func execute(id: UUID) async throws {}
    func markAllRead() async throws {}
}

final class MockMarkNotificationClickedUseCase: MarkNotificationClickedUseCaseProtocol, Sendable {
    func execute(id: UUID) async throws {}
}

final class MockMarkInboxSeenUseCase: MarkInboxSeenUseCaseProtocol, Sendable {
    func execute() async throws {}
}

#Preview("Notifications") {
    let previewLanguageService = LanguageService(userDefaults: UserDefaultsService())
    return NotificationListView(
        viewModel: NotificationListViewModel(
            fetchNotificationsUseCase: MockFetchNotificationsUseCase(),
            markReadUseCase: MockMarkNotificationReadUseCase(),
            markClickedUseCase: MockMarkNotificationClickedUseCase(),
            markInboxSeenUseCase: MockMarkInboxSeenUseCase(),
            languageService: previewLanguageService
        )
    )
    .environmentObject(previewLanguageService)
}

#endif
