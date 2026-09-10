import SwiftUI
import UIKit
import DesignSystem
import Localization

struct GroupAvatarSheet: View {
    let groupName: String
    let currentAvatarURL: URL?
    let onSave: (Data) async throws -> String

    @EnvironmentObject private var languageService: LanguageService

    private let previewDiameter: CGFloat = 192

    var body: some View {
        ImageCropSheet(
            title: languageService.text(.messagingGroupChangeAvatar),
            emptyHint: languageService.text(.messagingGroupChangeAvatarHint),
            alignHint: languageService.text(.messagingGroupAvatarAlignHint),
            changePhotoTitle: languageService.text(.messagingGroupChangePhoto),
            loadErrorText: languageService.text(.messagingGroupChangeAvatarLoadError),
            saveTitle: languageService.text(.commonSave)
        ) { image in
            guard let data = image.jpegData(compressionQuality: 0.85) else {
                throw ImageCropEncodeError(
                    message: languageService.text(.messagingGroupChangeAvatarLoadError)
                )
            }
            _ = try await onSave(data)
        } emptyContent: {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(imageURL: currentAvatarURL, name: groupName, size: .large)
                    .scaleEffect(previewDiameter / 72)
                    .frame(width: previewDiameter, height: previewDiameter)
                    .clipShape(Circle())

                Image(systemName: "camera.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Circle().fill(SplickTheme.Colors.primaryGradientStart))
                    .offset(x: 8, y: 8)
            }
        }
        .environmentObject(languageService)
    }
}

private struct ImageCropEncodeError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
