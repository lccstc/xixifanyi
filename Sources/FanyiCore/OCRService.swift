import AppKit
import Foundation
import Vision

public enum OCRServiceError: LocalizedError, Equatable {
    case invalidImage
    case noTextFound

    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            "无法读取选中的图像。"
        case .noTextFound:
            "选中区域没有识别到文字。"
        }
    }
}

public final class OCRService: @unchecked Sendable {
    public init() {}

    public func recognizeText(in image: NSImage) async throws -> String {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRServiceError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if text.isEmpty {
                    continuation.resume(throwing: OCRServiceError.noTextFound)
                } else {
                    continuation.resume(returning: text)
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "zh-Hans"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
