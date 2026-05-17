import Foundation

public protocol Repository {
    associatedtype Entity: Identifiable

    func getById(_ id: Entity.ID) async throws -> Entity?
    func getAll() async throws -> [Entity]
    func save(_ entity: Entity) async throws -> Entity
    func delete(_ id: Entity.ID) async throws
}
