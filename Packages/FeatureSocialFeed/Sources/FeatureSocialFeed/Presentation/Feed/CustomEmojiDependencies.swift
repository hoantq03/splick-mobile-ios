import Foundation
import SwiftUI
import Common
import FeatureMedia
import FeatureStickers

public struct CustomEmojiDependencies {
    public let fetcher: any CustomEmojiFetching
    public let uploadMediaUseCase: UploadMediaUseCaseProtocol
    public let addEmojiUseCase: AddGroupCustomEmojiUseCaseProtocol
    public let deleteEmojiUseCase: DeleteGroupCustomEmojiUseCaseProtocol

    public init(
        fetcher: any CustomEmojiFetching,
        uploadMediaUseCase: UploadMediaUseCaseProtocol,
        addEmojiUseCase: AddGroupCustomEmojiUseCaseProtocol,
        deleteEmojiUseCase: DeleteGroupCustomEmojiUseCaseProtocol
    ) {
        self.fetcher = fetcher
        self.uploadMediaUseCase = uploadMediaUseCase
        self.addEmojiUseCase = addEmojiUseCase
        self.deleteEmojiUseCase = deleteEmojiUseCase
    }
}

private struct CustomEmojiDependenciesKey: EnvironmentKey {
    static let defaultValue: CustomEmojiDependencies? = nil
}

extension EnvironmentValues {
    public var customEmojiDependencies: CustomEmojiDependencies? {
        get { self[CustomEmojiDependenciesKey.self] }
        set { self[CustomEmojiDependenciesKey.self] = newValue }
    }
}
