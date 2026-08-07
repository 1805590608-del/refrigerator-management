import Foundation
import UIKit
import PhotosUI

// MARK: - Image Compression Service

struct ImageService {

    /// Maximum long edge in pixels for compressed images.
    static let maxLongEdge: CGFloat = 1600
    /// JPEG compression quality.
    static let jpegQuality: CGFloat = 0.75

    /// Resizes and compresses a UIImage to JPEG data.
    static func compress(_ image: UIImage) -> Data? {
        let resized = resize(image, maxLongEdge: maxLongEdge)
        return resized.jpegData(compressionQuality: jpegQuality)
    }

    static func resize(_ image: UIImage, maxLongEdge: CGFloat) -> UIImage {
        let size = image.size
        let longEdge = max(size.width, size.height)
        guard longEdge > maxLongEdge else { return image }

        let scale = maxLongEdge / longEdge
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
