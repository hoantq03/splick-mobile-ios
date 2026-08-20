import CoreImage
import Foundation

struct LUTCube {
    let size: Int
    let data: Data
}

enum LUTCubeLoader {
    static func load(named resourceName: String, bundle: Bundle = .module) throws -> LUTCube {
        guard let url = bundle.url(forResource: resourceName, withExtension: "cube", subdirectory: "LUTs")
            ?? bundle.url(forResource: resourceName, withExtension: "cube")
        else {
            throw LUTCubeError.missingResource(resourceName)
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        return try parse(text)
    }

    static func parse(_ text: String) throws -> LUTCube {
        var size = 0
        var values: [Float] = []
        values.reserveCapacity(17 * 17 * 17 * 4)

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") || line.uppercased().hasPrefix("TITLE") {
                continue
            }
            if line.uppercased().hasPrefix("LUT_3D_SIZE") {
                let parts = line.split(whereSeparator: \.isWhitespace)
                guard let last = parts.last, let parsed = Int(last), parsed > 1 else {
                    throw LUTCubeError.invalidSize
                }
                size = parsed
                continue
            }
            if line.uppercased().hasPrefix("DOMAIN_") {
                continue
            }
            let parts = line.split(whereSeparator: \.isWhitespace)
            guard parts.count >= 3,
                  let r = Float(parts[0]),
                  let g = Float(parts[1]),
                  let b = Float(parts[2])
            else { continue }
            values.append(contentsOf: [r, g, b, 1])
        }

        guard size > 1 else { throw LUTCubeError.invalidSize }
        let expected = size * size * size * 4
        guard values.count == expected else {
            throw LUTCubeError.unexpectedSampleCount(expected: expected, actual: values.count)
        }
        return LUTCube(size: size, data: values.withUnsafeBufferPointer { Data(buffer: $0) })
    }
}

enum LUTCubeError: Error, Equatable {
    case missingResource(String)
    case invalidSize
    case unexpectedSampleCount(expected: Int, actual: Int)
}

enum LUTFilterProcessor {
    private static var cache: [String: LUTCube] = [:]
    private static let lock = NSLock()

    static func apply(_ image: CIImage, cubeName: String, intensity: Float) -> CIImage {
        guard intensity > 0.01, let cube = cube(named: cubeName),
              let cubeFilter = CIFilter(name: "CIColorCube")
        else { return image }
        cubeFilter.setValue(cube.size, forKey: "inputCubeDimension")
        cubeFilter.setValue(cube.data, forKey: "inputCubeData")
        cubeFilter.setValue(image, forKey: kCIInputImageKey)
        guard let filtered = cubeFilter.outputImage else { return image }
        return mix(original: image, filtered: filtered, intensity: intensity)
    }

    static func mix(original: CIImage, filtered: CIImage, intensity: Float) -> CIImage {
        let amount = min(max(intensity, 0), 1)
        if amount >= 0.99 { return filtered }
        guard let dissolve = CIFilter(name: "CIDissolveTransition") else { return filtered }
        dissolve.setValue(original, forKey: kCIInputImageKey)
        dissolve.setValue(filtered, forKey: kCIInputTargetImageKey)
        dissolve.setValue(amount, forKey: kCIInputTimeKey)
        return dissolve.outputImage ?? filtered
    }

    private static func cube(named name: String) -> LUTCube? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[name] { return cached }
        guard let cube = try? LUTCubeLoader.load(named: name) else { return nil }
        cache[name] = cube
        return cube
    }
}
