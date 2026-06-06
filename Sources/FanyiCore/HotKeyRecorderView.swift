import AppKit
import Carbon
import SwiftUI

public struct HotKeyRecorderView: NSViewRepresentable {
    @Binding private var config: HotKeyConfig

    public init(config: Binding<HotKeyConfig>) {
        self._config = config
    }

    public func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.onRecord = { keyCode, modifiers, displayName in
            config = HotKeyConfig(keyCode: keyCode, carbonModifiers: modifiers, displayName: displayName)
        }
        button.title = config.displayName
        return button
    }

    public func updateNSView(_ nsView: RecorderButton, context: Context) {
        nsView.title = nsView.isRecording ? "请按新的快捷键..." : config.displayName
    }
}

public final class RecorderButton: NSButton {
    var onRecord: ((UInt32, UInt32, String) -> Void)?
    var isRecording = false

    public init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(beginRecording)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var acceptsFirstResponder: Bool { true }

    @objc private func beginRecording() {
        isRecording = true
        title = "请按新的快捷键..."
        window?.makeFirstResponder(self)
    }

    public override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 53 {
            isRecording = false
            needsDisplay = true
            return
        }

        let modifiers = Self.carbonModifiers(from: event.modifierFlags)
        guard modifiers != 0 else {
            title = "请同时按下 ⌘ / ⌃ / ⌥ / ⇧"
            return
        }

        let keyCode = UInt32(event.keyCode)
        let displayName = Self.displayName(keyCode: event.keyCode, modifierFlags: event.modifierFlags)
        isRecording = false
        onRecord?(keyCode, modifiers, displayName)
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        return result
    }

    private static func displayName(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if modifierFlags.contains(.control) { parts.append("⌃") }
        if modifierFlags.contains(.option) { parts.append("⌥") }
        if modifierFlags.contains(.shift) { parts.append("⇧") }
        if modifierFlags.contains(.command) { parts.append("⌘") }
        parts.append(keyName(for: keyCode))
        return parts.joined(separator: " + ")
    }

    private static func keyName(for keyCode: UInt16) -> String {
        let names: [UInt16: String] = [
            122: "F1", 120: "F2", 99: "F3", 118: "F4",
            96: "F5", 97: "F6", 98: "F7", 100: "F8",
            101: "F9", 109: "F10", 103: "F11", 111: "F12",
            105: "F13", 107: "F14", 113: "F15", 106: "F16",
            64: "F17", 79: "F18", 80: "F19",
            49: "空格", 36: "回车", 48: "Tab", 53: "Esc",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            51: "删除", 117: "向前删除"
        ]
        if let name = names[keyCode] {
            return name
        }

        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "Key \(keyCode)"
        }
        let data = unsafeBitCast(layoutData, to: CFData.self)
        let keyboardLayout = unsafeBitCast(CFDataGetBytePtr(data), to: UnsafePointer<UCKeyboardLayout>.self)
        var deadKeyState: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let status = UCKeyTranslate(
            keyboardLayout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )
        if status == noErr, length > 0 {
            return String(utf16CodeUnits: chars, count: length).uppercased()
        }
        return "Key \(keyCode)"
    }
}
