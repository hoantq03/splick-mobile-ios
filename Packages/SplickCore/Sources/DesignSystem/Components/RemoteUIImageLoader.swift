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
        let wantsAnimation = animated && url.isLikelyAnimatedImage

        if wantsAnimation {
            let task = ImagePipeline.shared.loadData(with: ImageRequest(url: url)) { result in
                switch result {
                case .success(let (data, _)):
                    DispatchQueue.global(qos: .userInitiated).async {
                        let image = GIFAnimatedImageFactory.animatedImage(
                            from: data,
                            maxPixelSize: maxPixelSize
                        ) ?? GIFAnimatedImageFactory.firstFrame(from: data, maxPixelSize: maxPixelSize)
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
                DispatchQueue.global(qos: .userInitiated).async {
                    let image: UIImage
                    if url.isLikelyAnimatedImage {
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
