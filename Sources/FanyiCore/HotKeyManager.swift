import Carbon
import Foundation

public enum HotKeyAction: UInt32, CaseIterable {
    case screenshot = 1
    case selection = 2
    case draft = 3
}

@MainActor
public final class HotKeyManager {
    private var hotKeys: [HotKeyAction: EventHotKeyRef] = [:]
    private var callback: ((HotKeyAction) -> Void)?
    private var eventHandler: EventHandlerRef?

    public init() {}

    public func register(configuration: AppConfiguration, callback: @escaping (HotKeyAction) -> Void) {
        unregisterAll()
        self.callback = callback
        installHandlerIfNeeded()
        register(action: .screenshot, config: configuration.screenshotHotKey)
        register(action: .selection, config: configuration.selectionHotKey)
        register(action: .draft, config: configuration.draftHotKey)
    }

    public func unregisterAll() {
        for ref in hotKeys.values {
            UnregisterEventHotKey(ref)
        }
        hotKeys.removeAll()
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in
                if let action = HotKeyAction(rawValue: hotKeyID.id) {
                    manager.callback?(action)
                }
            }
            return noErr
        }, 1, &eventType, selfPointer, &eventHandler)
    }

    private func register(action: HotKeyAction, config: HotKeyConfig) {
        let hotKeyID = EventHotKeyID(signature: OSType(0x46414E59), id: action.rawValue)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(config.keyCode, config.carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            hotKeys[action] = ref
        }
    }
}
