import UIKit

/// One item confirmed from the in-app photo/video library picker.
public enum LibraryPickedMedia: Equatable {
    case image(UIImage)
    case video(URL)
}
