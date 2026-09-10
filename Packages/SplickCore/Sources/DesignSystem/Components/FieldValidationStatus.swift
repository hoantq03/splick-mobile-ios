import SwiftUI

public enum FieldValidationStatus: Equatable, Sendable {
    case neutral
    case loading
    case valid
    case warning
}
