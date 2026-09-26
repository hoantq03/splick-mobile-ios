import Foundation
import Common
import FeatureNotification

protocol DeviceTokenServiceProtocol: Sendable {
    func registerCurrentDeviceToken(_ token: String) async throws
    func unregisterDeviceToken(_ token: String) async throws
}

actor DeviceTokenService: DeviceTokenServiceProtocol {
    private let registerUseCase: RegisterPushDeviceTokenUseCaseProtocol
    private let unregisterUseCase: UnregisterPushDeviceTokenUseCaseProtocol

    init(
        registerUseCase: RegisterPushDeviceTokenUseCaseProtocol,
        unregisterUseCase: UnregisterPushDeviceTokenUseCaseProtocol
    ) {
        self.registerUseCase = registerUseCase
        self.unregisterUseCase = unregisterUseCase
    }

    func registerCurrentDeviceToken(_ token: String) async throws {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.splick.app"
        let environment = PushEnvironmentResolver.current.rawValue

        do {
            try await registerUseCase.execute(
                token: token,
                bundleId: bundleId,
                environment: environment
            )
            Log.info(
                "Registered push device token",
                category: .notification,
                metadata: [
                    "bundleId": bundleId,
                    "environment": environment,
                    "tokenSuffix": token.suffix(8).description,
                ]
            )
        } catch {
            Log.error(
                "Failed to register push device token",
                category: .notification,
                metadata: [
                    "bundleId": bundleId,
                    "environment": environment,
                    "tokenSuffix": token.suffix(8).description,
                    "error": error.localizedDescription,
                ]
            )
            throw error
        }
    }

    func unregisterDeviceToken(_ token: String) async throws {
        do {
            try await unregisterUseCase.execute(token: token)
            Log.info(
                "Unregistered push device token",
                category: .notification,
                metadata: ["tokenSuffix": token.suffix(8).description]
            )
        } catch {
            Log.error(
                "Failed to unregister push device token",
                category: .notification,
                metadata: [
                    "tokenSuffix": token.suffix(8).description,
                    "error": error.localizedDescription,
                ]
            )
            throw error
        }
    }
}

private enum PushEnvironmentResolver: String {
    case sandbox
    case production

    static var current: PushEnvironmentResolver {
#if DEBUG
        return .sandbox
#else
        return .production
#endif
    }
}
