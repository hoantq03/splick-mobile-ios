import Foundation

public struct PasswordRequirementGuideItem: Equatable, Hashable, Sendable, Identifiable {
    public var id: String { label }
    public let label: String
    public let met: Bool

    public init(label: String, met: Bool) {
        self.label = label
        self.met = met
    }
}
