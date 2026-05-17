import Foundation

public protocol UseCase {
    associatedtype Input
    associatedtype Output

    func execute(_ input: Input) async throws -> Output
}

public protocol NoInputUseCase {
    associatedtype Output

    func execute() async throws -> Output
}

public protocol StreamUseCase {
    associatedtype Input
    associatedtype Output

    func execute(_ input: Input) -> AsyncThrowingStream<Output, Error>
}
