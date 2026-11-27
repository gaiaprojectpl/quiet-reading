import SwiftUI
import VisionKit
import Vision
import AVFoundation
import CoreImage

/// Live camera for Flow 2, using Apple's on-device DataScanner.
/// - Cover: plain camera; the shutter takes a photo, then Vision reads the title on the phone.
/// - Barcode: reads EAN-13 (ISBN) barcodes continuously.
struct CameraScanner: UIViewControllerRepresentable {
    enum Kind { case cover, barcode }
    let kind: Kind
    let controller: CameraController
    var onISBN: (String) -> Void = { _ in }

    static var isAvailable: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let types: Set<DataScannerViewController.RecognizedDataType> = kind == .barcode
            ? [.barcode(symbologies: [.ean13])]
            : [.text()]
        let scanner = DataScannerViewController(
            recognizedDataTypes: types,
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: kind == .barcode
        )
        scanner.delegate = context.coordinator
        controller.scanner = scanner
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onISBN = onISBN
        if !scanner.isScanning { try? scanner.startScanning() }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onISBN: onISBN) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onISBN: (String) -> Void
        private var reported: String?
        init(onISBN: @escaping (String) -> Void) { self.onISBN = onISBN }

        func dataScanner(_ scanner: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in items {
                guard case .barcode(let code) = item, let value = code.payloadStringValue,
                      value.count == 13, value.hasPrefix("978") || value.hasPrefix("979"),
                      value != reported else { continue }
                reported = value
                onISBN(value)
            }
        }
    }
}

/// Talks to the running scanner: photo capture and the torch.
@Observable
final class CameraController {
    weak var scanner: DataScannerViewController?
    private(set) var torchOn = false

    func capturePhoto() async -> UIImage? {
        try? await scanner?.capturePhoto()
    }

    func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch,
              (try? device.lockForConfiguration()) != nil else { return }
        torchOn.toggle()
        device.torchMode = torchOn ? .on : .off
        device.unlockForConfiguration()
    }

    func torchOff() {
        guard torchOn else { return }
        toggleTorch()
    }
}

// MARK: - Reading the cover (on the phone)

nonisolated enum CoverReader {
    struct Result: Sendable {
        /// Biggest lines first – usually the title, then the author.
        var lines: [String]
        var isTooDark: Bool
        var query: String { lines.prefix(2).joined(separator: " ") }
    }

    static func read(_ image: UIImage) async -> Result {
        guard let cg = image.cgImage else { return Result(lines: [], isTooDark: false) }
        let dark = averageBrightness(cg) < 0.12
        let lines: [String] = await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let sorted = observations
                    .filter { ($0.topCandidates(1).first?.confidence ?? 0) > 0.3 }
                    .sorted { $0.boundingBox.height > $1.boundingBox.height }
                let text = sorted.compactMap { $0.topCandidates(1).first?.string }
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0.count > 1 }
                continuation.resume(returning: Array(text.prefix(4)))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cg, orientation: .init(image.imageOrientation))
            do { try handler.perform([request]) } catch { continuation.resume(returning: []) }
        }
        return Result(lines: lines, isTooDark: dark && lines.isEmpty)
    }

    private static func averageBrightness(_ cg: CGImage) -> Double {
        let image = CIImage(cgImage: cg)
        let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: image, kCIInputExtentKey: CIVector(cgRect: image.extent)])
        guard let output = filter?.outputImage else { return 1 }
        var pixel = [UInt8](repeating: 0, count: 4)
        CIContext().render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        return (0.299 * Double(pixel[0]) + 0.587 * Double(pixel[1]) + 0.114 * Double(pixel[2])) / 255
    }
}

nonisolated private extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

extension UIImage {
    /// JPEG for storing as a cover, at most 600 pt wide.
    func coverJPEG() -> Data? {
        let maxWidth: CGFloat = 600
        let scale = min(1, maxWidth / size.width)
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let resized = UIGraphicsImageRenderer(size: target).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
