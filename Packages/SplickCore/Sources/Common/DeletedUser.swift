import Foundation

public enum DeletedUser {
    public static let displayName = "Deleted User"

    public static func isDeleted(displayName name: String) -> Bool {
        name == displayName
    }
}
