import ApplicationServices
import CoreGraphics
import Foundation

public enum PermissionService {
    public static func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    public static func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    public static func hasScreenCapturePermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    public static func requestScreenCapturePermission() {
        CGRequestScreenCaptureAccess()
    }
}
