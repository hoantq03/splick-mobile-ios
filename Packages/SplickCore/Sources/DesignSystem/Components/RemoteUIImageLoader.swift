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
                let image: UIImage
                if url.isLikelyAnimatedImage {
                    image = GIFAnimatedImageFactory.uiImage(
                        from: response.container,
                        maxPixelSize: maxPixelSize
                    )
                } else {
                    image = response.image
                }
                completion(image)
            case .failure:
                completion(nil)
            }
        }

        return RemoteUIImageLoadHandle(task: task)
    }
}
