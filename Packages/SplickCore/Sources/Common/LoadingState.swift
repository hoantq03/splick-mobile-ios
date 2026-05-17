import Foundation

public enum LoadingState<T: Equatable>: Equatable {
    case idle
    case loading
    case loaded(T)
    case failed(String)

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    public var value: T? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    public var error: String? {
        if case .failed(let message) = self { return message }
        return nil
    }
}
