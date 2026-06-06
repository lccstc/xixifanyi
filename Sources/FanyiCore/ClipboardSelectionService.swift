import AppKit
import ApplicationServices
import Foundation

public struct PasteboardSnapshot {
    private struct Item {
        var representations: [(NSPasteboard.PasteboardType, Data)]
    }

    private var items: [Item]

    public static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            Item(representations: item.types.compactMap { type in
                guard let data = item.data(forType: type) else {
                    return nil
                }
                return (type, data)
            })
        }
        return PasteboardSnapshot(items: items)
    }

    public func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else {
            return
        }

        let restoredItems = items.map { snapshotItem in
            let pasteboardItem = NSPasteboardItem()
            for (type, data) in snapshotItem.representations {
                pasteboardItem.setData(data, forType: type)
            }
            return pasteboardItem
        }
        pasteboard.writeObjects(restoredItems)
    }
}

@MainActor
public final class ClipboardSelectionService {
    public init() {}

    public func currentSelectedText() async -> String? {
        if let text = selectedTextFromAccessibility(), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }
        return await selectedTextFromCopyFallback()
    }

    private func selectedTextFromAccessibility() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused else {
            return nil
        }

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func selectedTextFromCopyFallback() async -> String? {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot.capture(from: pasteboard)
        let oldChangeCount = pasteboard.changeCount
        sendCopyShortcut()

        try? await Task.sleep(nanoseconds: 200_000_000)
        let newString = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if pasteboard.changeCount != oldChangeCount {
            snapshot.restore(to: pasteboard)
        }
        return newString?.isEmpty == false ? newString : nil
    }

    private func sendCopyShortcut() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
