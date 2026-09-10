import SwiftUI
import UIKit
import DesignSystem
import Localization

public struct ProfileAvatarCropSheet: View {
    let sourceImage: UIImage
    let onSave: (UIImage) async throws -> Void

    @EnvironmentObject private var languageService: LanguageService

    public init(sourceImage: UIImage, onSave: @escaping (UIImage) async throws -> Void) {
        self.sourceImage = sourceImage
        self.onSave = onSave
    }

    public var body: some View {
        ImageCropSheet(
            title: languageService.text(.profileAvatarEdit),
            emptyHint: languageService.text(.profileAvatarChangeHint),
            alignHint: languageService.text(.messagingGroupAvatarAlignHint),
            changePhotoTitle: languageService.text(.messagingGroupChangePhoto),
            loadErrorText: languageService.text(.profileAvatarLoadFailed),
            saveTitle: languageService.text(.profileSave),
            initialImage: sourceImage,
            onSave: onSave
        )
        .environmentObject(languageService)
    }
}
