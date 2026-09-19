import Foundation

public enum PostUploadState: Equatable, Sendable {
    case uploading
    case failed(message: String)
}
