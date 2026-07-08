import AppKit
import Carbon.HIToolbox

/// System-wide hotkeys via Carbon `RegisterEventHotKey`, which works without
/// Accessibility/Input Monitoring permission (unlike NSEvent global monitors).
/// Delivers both press and release so callers can implement
/// tap-to-toggle / hold-for-push-to-talk on a single binding.
@MainActor
final class HotKeyCenter {
    private struct Registration {
        var ref: EventHotKeyRef
        var onPress: () -> Void
        var onRelease: () -> Void
    }

    private static let signature: OSType = 0x5653_4C56 // 'VSLV'
    private static let mainHotKeyID: UInt32 = 1
    private static let escapeHotKeyID: UInt32 = 2

    private var handlerRef: EventHandlerRef?
    private var registrations: [UInt32: Registration] = [:]

    @discardableResult
    func registerMain(
        _ shortcut: KeyboardShortcut,
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void
    ) -> Bool {
        unregister(id: Self.mainHotKeyID)
        return register(
            id: Self.mainHotKeyID,
            keyCode: UInt32(shortcut.keyCode),
            carbonModifiers: shortcut.carbonModifiers,
            onPress: onPress,
            onRelease: onRelease
        )
    }

    func unregisterMain() {
        unregister(id: Self.mainHotKeyID)
    }

    /// Registered only while a recording is active so Esc cancels dictation
    /// globally without permanently swallowing the key.
    @discardableResult
    func registerEscape(onPress: @escaping () -> Void) -> Bool {
        unregister(id: Self.escapeHotKeyID)
        return register(
            id: Self.escapeHotKeyID,
            keyCode: UInt32(kVK_Escape),
            carbonModifiers: 0,
            onPress: onPress,
            onRelease: {}
        )
    }

    func unregisterEscape() {
        unregister(id: Self.escapeHotKeyID)
    }

    private func register(
        id: UInt32,
        keyCode: UInt32,
        carbonModifiers: UInt32,
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void
    ) -> Bool {
        installHandlerIfNeeded()
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return false }
        registrations[id] = Registration(ref: ref, onPress: onPress, onRelease: onRelease)
        return true
    }

    private func unregister(id: UInt32) {
        if let registration = registrations.removeValue(forKey: id) {
            UnregisterEventHotKey(registration.ref)
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr, hotKeyID.signature == HotKeyCenter.signature else {
                    return OSStatus(eventNotHandledErr)
                }
                let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
                let id = hotKeyID.id
                let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        center.dispatch(id: id, pressed: pressed)
                    }
                }
                return noErr
            },
            eventTypes.count,
            &eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }

    private func dispatch(id: UInt32, pressed: Bool) {
        guard let registration = registrations[id] else { return }
        if pressed {
            registration.onPress()
        } else {
            registration.onRelease()
        }
    }
}
