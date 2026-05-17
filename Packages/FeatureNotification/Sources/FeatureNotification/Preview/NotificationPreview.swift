import Foundation
import SwiftUI
import SplickDomain

#if DEBUG

final class MockFetchNotificationsUseCase: FetchNotificationsUseCaseProtocol, Sendable {
    func execute(page: Int) async throws -> [AppNotification] {
        try await Task.sleep(for: .milliseconds(500))
        return PreviewData.sampleNotifications
    }
}

final class MockMarkNotificationReadUseCase: MarkNotificationReadUseCaseProtocol, Sendable {
    func execute(id: UUID) async throws {}
    func markAllRead() async throws {}
}

#Preview("Notifications") {
    NotificationListView(
        viewModel: NotificationListViewModel(
            fetchNotificationsUseCase: MockFetchNotificationsUseCase(),
            markReadUseCase: MockMarkNotificationReadUseCase()
        )
    )
}

#endif
