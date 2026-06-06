import AppKit
import SwiftUI

@MainActor
public final class FloatingResultWindowController {
    private var window: NSWindow?

    public init() {}

    public func show(title: String, body: String) {
        let content = FloatingResultView(title: title, message: body) { [weak self] in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(body, forType: .string)
            self?.window?.close()
        } onClose: { [weak self] in
            self?.window?.close()
        }
        let controller = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: controller)
        window.title = title
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 420, height: 240))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}

private struct FloatingResultView: View {
    var title: String
    var message: String
    var onCopy: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("关闭", action: onClose)
            }
            ScrollView {
                Text(message)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .font(.body)
            }
            HStack {
                Spacer()
                Button("复制", action: onCopy)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(minWidth: 360, minHeight: 180)
    }
}
