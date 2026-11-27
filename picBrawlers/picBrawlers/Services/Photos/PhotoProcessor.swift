import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated enum PhotoProcessingError: Error, Equatable {
    /// The data isn't an image the system can decode.
    case unreadable
}

/// Turns a picked photo into the image stored on the card.
nonisolated protocol PhotoProcessing: Sendable {
    func prepare(_ data: Data) async throws -> Data
}

/// Shrinks the photo so its long side is at most `maxPixelSize`, applies its orientation and saves it
/// as JPEG. Big enough for a full-width card on a 3× screen, small enough to send to an opponent later.
nonisolated struct PhotoProcessor: PhotoProcessing {
    static let maxPixelSize = 1200
    static let compressionQuality = 0.8

    @concurrent
    func prepare(_ data: Data) async throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { throw PhotoProcessingError.unreadable }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: min(Self.maxPixelSize, max(width, height)),
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw PhotoProcessingError.unreadable
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw PhotoProcessingError.unreadable
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: Self.compressionQuality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw PhotoProcessingError.unreadable }
        return output as Data
    }
}
