import Foundation

public protocol UserDefaultsServiceProtocol {
    func set<T: Codable>(_ value: T, for key: String)
    func get<T: Codable>(for key: String) -> T?
    func setBool(_ value: Bool, for key: String)
    func getBool(for key: String) -> Bool
    func remove(for key: String)
}

public final class UserDefaultsService: UserDefaultsServiceProtocol {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func set<T: Codable>(_ value: T, for key: String) {
        if let data = try? encoder.encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    public func get<T: Codable>(for key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    public func setBool(_ value: Bool, for key: String) {
        defaults.set(value, forKey: key)
    }

    public func getBool(for key: String) -> Bool {
        defaults.bool(forKey: key)
    }

    public func remove(for key: String) {
        defaults.removeObject(forKey: key)
    }
}
