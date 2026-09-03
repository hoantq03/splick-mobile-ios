import SwiftUI

public typealias SharePostViewModelFactory = (URL) -> SharePostViewModel

private struct SharePostViewModelFactoryKey: EnvironmentKey {
    static let defaultValue: SharePostViewModelFactory? = nil
}

public extension EnvironmentValues {
    var makeSharePostViewModel: SharePostViewModelFactory? {
        get { self[SharePostViewModelFactoryKey.self] }
        set { self[SharePostViewModelFactoryKey.self] = newValue }
    }
}
