import UIKit
import Vision
import CoreImage

/// Turns a photo of a book into a cover: finds the book's rectangle, straightens it,
/// and falls back to a centred 2:3 crop when no clear rectangle is found. All on the phone.
nonisolated enum CoverCropper {
    static func crop(_ image: UIImage) async -> UIImage {
        guard let cg = image.normalized().cgImage else { return image }
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.45
        request.maximumAspectRatio = 0.95
        request.minimumSize = 0.25
        request.minimumConfidence = 0.6
        request.maximumObservations = 1
        try? VNImageRequestHandler(cgImage: cg).perform([request])
        if let r = request.results?.first, let straight = straighten(cg, r) { return straight }
        return centred(cg)
    }

    private static func straighten(_ cg: CGImage, _ r: VNRectangleObservation) -> UIImage? {
        let ci = CIImage(cgImage: cg)
        let size = ci.extent.size
        func p(_ n: CGPoint) -> CIVector { CIVector(x: n.x * size.width, y: n.y * size.height) }
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(p(r.topLeft), forKey: "inputTopLeft")
        filter.setValue(p(r.topRight), forKey: "inputTopRight")
        filter.setValue(p(r.bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(p(r.bottomRight), forKey: "inputBottomRight")
        guard let out = filter.outputImage,
              let result = CIContext().createCGImage(out, from: out.extent) else { return nil }
        let img = UIImage(cgImage: result)
        // A cover is taller than wide; a sideways result means the detection was off.
        return img.size.height > img.size.width ? img : nil
    }

    private static func centred(_ cg: CGImage) -> UIImage {
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let targetW = min(w, h * 2 / 3), targetH = targetW * 3 / 2
        let rect = CGRect(x: (w - targetW) / 2, y: (h - targetH) / 2, width: targetW, height: targetH).integral
        return cg.cropping(to: rect).map { UIImage(cgImage: $0) } ?? UIImage(cgImage: cg)
    }
}

private extension UIImage {
    /// Bakes the camera orientation into the pixels so Vision sees the photo upright.
    nonisolated func normalized() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }
}
