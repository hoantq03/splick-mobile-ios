import Foundation

struct RegisterPushDeviceRequestDTO: Encodable {
    let token: String
    let platform: String
    let bundleId: String
    let environment: String
}
