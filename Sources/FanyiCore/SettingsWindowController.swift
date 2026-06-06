import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowController {
    private var window: NSWindow?
    private let store: AppSettingsStore
    private let client: TranslationClient
    private let onSave: () -> Void

    public init(store: AppSettingsStore, client: TranslationClient = OpenAITranslationClient(), onSave: @escaping () -> Void) {
        self.store = store
        self.client = client
        self.onSave = onSave
    }

    public func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView(store: store, client: client, onSave: onSave)
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "FanyiBar 设置"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 780, height: 820))
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
