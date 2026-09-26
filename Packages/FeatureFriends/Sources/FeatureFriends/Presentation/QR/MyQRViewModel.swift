import Foundation
import Common

@MainActor
final class MyQRViewModel: ObservableObject {
    @Published private(set) var payload: String?
    @Published private(set) var version: Int?
    @Published var state: LoadingState<PersonalQRCode> = .idle
    @Published var alertMessage: String?

    private let generateMyQrUseCase: GenerateMyQrUseCaseProtocol

    init(generateMyQrUseCase: GenerateMyQrUseCaseProtocol) {
        self.generateMyQrUseCase = generateMyQrUseCase
    }

    func load() async {
        state = .loading
        alertMessage = nil
        do {
            let qr = try await generateMyQrUseCase.execute()
            payload = qr.payload
            version = qr.version
            state = .loaded(qr)
        } catch {
            payload = nil
            version = nil
            state = .failed(error.localizedDescription)
        }
    }

    func refresh() async {
        await load()
    }
}
