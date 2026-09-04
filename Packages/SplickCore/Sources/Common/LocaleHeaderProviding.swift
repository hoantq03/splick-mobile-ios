import Foundation

public protocol LocaleHeaderProviding: Sendable {
    func acceptLanguageHeader() async -> String
}
