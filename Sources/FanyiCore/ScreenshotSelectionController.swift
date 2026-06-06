import AppKit
import Foundation

@MainActor
public final class ScreenshotSelectionController {
    private var runningProcess: Process?

    public init() {}

    public func beginSelection(completion: @escaping @MainActor @Sendable (NSImage?) -> Void) {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FanyiBar-Screenshot-\(UUID().uuidString).png")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-x", "-t", "png", outputURL.path]
        runningProcess = process

        process.terminationHandler = { [weak self] process in
            let image = NSImage(contentsOf: outputURL)
            try? FileManager.default.removeItem(at: outputURL)
            Task { @MainActor in
                self?.runningProcess = nil
                completion(process.terminationStatus == 0 ? image : nil)
            }
        }

        do {
            try process.run()
        } catch {
            runningProcess = nil
            completion(nil)
        }
    }

    public func cancel() {
        runningProcess?.terminate()
        runningProcess = nil
    }

    public static func quartzRect(from appKitRect: CGRect, screenFrame: CGRect) -> CGRect {
        CGRect(
            x: appKitRect.minX,
            y: screenFrame.maxY - appKitRect.maxY,
            width: appKitRect.width,
            height: appKitRect.height
        )
    }
}
