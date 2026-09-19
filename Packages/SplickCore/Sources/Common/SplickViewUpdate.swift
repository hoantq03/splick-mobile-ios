import Foundation

/// Escapes SwiftUI's view-update pass before mutating `ObservableObject`.
///
/// `DispatchQueue.main.async` and `Task { @MainActor in }` are often drained
/// *during* the same SwiftUI update (which logs "Publishing changes from within
/// view updates"). A 1ms deadline / sleep is not.
public enum SplickViewUpdate {
    public static func after(_ body: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1), execute: body)
    }

    @MainActor
    public static func hop() async {
        try? await Task.sleep(nanoseconds: 8_000_000)
    }
}
