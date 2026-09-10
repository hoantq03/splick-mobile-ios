import Foundation

public protocol DeviceTokenServiceProtocol: Sendable {
    func register(
        token: String,
        bundleId: String,
        environment: String
    ) async throws
    func unregister(token: String) async throws
}

public final class DeviceTokenService: DeviceTokenServiceProtocol, Sendable {
    private let registerUseCase: RegisterPushDeviceTokenUseCaseProtocol
    private let unregisterUseCase: UnregisterPushDeviceTokenUseCaseProtocol

    public init(
        registerUseCase: RegisterPushDeviceTokenUseCaseProtocol,
        unregisterUseCase: UnregisterPushDeviceTokenUseCaseProtocol
    ) {
        self.registerUseCase = registerUseCase
        self.unregisterUseCase = unregisterUseCase
    }

    public func register(
        token: String,
        bundleId: String,
        environment: String
    ) async throws {
        try await registerUseCase.execute(
            token: token,
            bundleId: bundleId,
            environment: environment
        )
    }

    public func unregister(token: String) async throws {
        try await unregisterUseCase.execute(token: token)
    }
}
