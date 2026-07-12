import Nuke
import UIKit
import Common

public final class RemoteUIImageLoadHandle {
    private var task: ImageTask?

    fileprivate init(task: ImageTask?) {
        self.task = task
    }

    public func cancel() {
        task?.cancel()
        task = nil
    }
}

public enum RemoteUIImageLoader {
    @discardableResult
    public static func load(
        url: URL,
        maxPixelSize: CGFloat? = nil,
        animated: Bool = true,
        completion: @escaping (UIImage?) -> Void
    ) -> RemoteUIImageLoadHandle {
        let request: ImageRequest
        if let maxPixelSize, maxPixelSize > 0 {
            request = RemoteImageRequestFactory.boundedRequest(url: url, maxPixelWidth: maxPixelSize)
        } else {
            request = ImageRequest(url: url)
        }

        let task = ImagePipeline.shared.loadImage(with: request) { result in
            switch result {
            case .success(let response):
                let container = response.container
                let wantsAnimation = animated && url.isLikelyAnimatedImage
                DispatchQueue.global(qos: .userInitiated).async {
                    let image: UIImage
                    if wantsAnimation {
                        image = GIFAnimatedImageFactory.uiImage(
                            from: container,
                            maxPixelSize: maxPixelSize
                        )
                    } else if url.isLikelyAnimatedImage {
                        image = GIFAnimatedImageFactory.firstFrame(
                            from: container,
                            maxPixelSize: maxPixelSize
                        )
                    } else {
                        image = container.image
                    }
                    DispatchQueue.main.async {
                        completion(image)
                    }
                }
            case .failure:
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }

        return RemoteUIImageLoadHandle(task: task)
    }
}
