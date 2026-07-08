import AppKit
import ApplicationServices
import AVFoundation
import Carbon.HIToolbox
import Foundation
import Security
import ServiceManagement
import Speech
import VoiceSlaveCore

struct KeyboardShortcut: Equatable {
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags
    let displayName: String

    static func parse(_ value: String) -> KeyboardShortcut? {
        let parts = value
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return nil }

        var modifiers: NSEvent.ModifierFlags = []
        var keyName: String?
        for part in parts {
            switch part {
            case "command", "cmd", "⌘":
                modifiers.insert(.command)
            case "control", "ctrl", "⌃":
                modifiers.insert(.control)
            case "option", "alt", "⌥":
                modifiers.insert(.option)
            case "shift", "⇧":
                modifiers.insert(.shift)
            default:
                guard keyName == nil else { return nil }
                keyName = part
            }
        }

        guard let keyName, let keyCode = keyCodes[keyName], !modifiers.isEmpty else {
            return nil
        }
        return KeyboardShortcut(
            keyCode: keyCode,
            modifiers: modifiers,
            displayName: displayName(modifiers: modifiers, keyName: keyName)
        )
    }

    /// Canonical settings-string for a captured key event,
    /// e.g. "control+option+space". Returns nil for bare modifiers
    /// or unknown keys.
    static func canonicalString(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String? {
        guard let keyName = keyNames[keyCode] else { return nil }
        let active = modifiers.intersection([.command, .control, .option, .shift])
        guard !active.isEmpty else { return nil }
        var pieces: [String] = []
        if active.contains(.control) { pieces.append("control") }
        if active.contains(.option) { pieces.append("option") }
        if active.contains(.shift) { pieces.append("shift") }
        if active.contains(.command) { pieces.append("command") }
        pieces.append(keyName)
        return pieces.joined(separator: "+")
    }

    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if modifiers.contains(.command) { value |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { value |= UInt32(shiftKey) }
        if modifiers.contains(.option) { value |= UInt32(optionKey) }
        if modifiers.contains(.control) { value |= UInt32(controlKey) }
        return value
    }

    /// Compact symbol form, e.g. "⌃⌥Space".
    var compactDisplay: String {
        var pieces = ""
        if modifiers.contains(.control) { pieces += "⌃" }
        if modifiers.contains(.option) { pieces += "⌥" }
        if modifiers.contains(.shift) { pieces += "⇧" }
        if modifiers.contains(.command) { pieces += "⌘" }
        let keyName = Self.keyNames[keyCode] ?? "?"
        let pretty: String
        switch keyName {
        case "space": pretty = "Space"
        case "return": pretty = "↩"
        case "tab": pretty = "⇥"
        case "escape": pretty = "⎋"
        case "left": pretty = "←"
        case "right": pretty = "→"
        case "up": pretty = "↑"
        case "down": pretty = "↓"
        default: pretty = keyName.count == 1 ? keyName.uppercased() : keyName.capitalized
        }
        return pieces + pretty
    }

    private static let keyCodes: [String: UInt16] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
        "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
        "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
        "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "return": 36,
        "enter": 36, "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42,
        ",": 43, "/": 44, "n": 45, "m": 46, ".": 47, "tab": 48,
        "space": 49, "`": 50, "escape": 53, "esc": 53,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
        "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
        "left": 123, "right": 124, "down": 125, "up": 126
    ]

    private static let keyNames: [UInt16: String] = {
        var names: [UInt16: String] = [:]
        for (name, code) in keyCodes where names[code] == nil {
            names[code] = name
        }
        names[36] = "return"
        names[53] = "escape"
        return names
    }()

    private static func displayName(modifiers: NSEvent.ModifierFlags, keyName: String) -> String {
        var pieces: [String] = []
        if modifiers.contains(.control) { pieces.append("Control") }
        if modifiers.contains(.option) { pieces.append("Option") }
        if modifiers.contains(.shift) { pieces.append("Shift") }
        if modifiers.contains(.command) { pieces.append("Command") }
        pieces.append(keyName == "space" ? "Space" : keyName.uppercased())
        return pieces.joined(separator: " + ")
    }
}

struct MacPermissionReader {
    func snapshot(modelSetupComplete: Bool) -> PermissionSnapshot {
        PermissionSnapshot(
            microphone: microphoneState(),
            speechRecognition: speechState(),
            accessibility: AXIsProcessTrusted() ? .granted : .denied,
            modelSetupComplete: modelSetupComplete
        )
    }

    func openMicrophoneSettings() {
        openSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }

    func openSpeechRecognitionSettings() {
        openSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")
    }

    func openAccessibilitySettings() {
        openSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    /// Shows the system accessibility-trust prompt for this app.
    func promptForAccessibility() {
        // kAXTrustedCheckOptionPrompt is a global var and not concurrency-safe
        // to reference under Swift 6; the literal key is ABI-stable.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private func microphoneState() -> PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    private func speechState() -> PermissionState {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    private func openSettingsPane(_ value: String) {
        guard let url = URL(string: value) else { return }
        NSWorkspace.shared.open(url)
    }
}

struct LaunchAtLoginController {
    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

final class KeychainAPIKeyStore {
    private let service = "com.hoyeon.VoiceSlave.openai"
    private let account = "OpenAI API Key"

    func save(_ key: String) throws {
        try delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(key.utf8)
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    func read() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
        guard let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }
}

struct KeychainError: Error, CustomStringConvertible {
    var status: OSStatus
    var description: String {
        SecCopyErrorMessageString(status, nil) as String? ?? "Keychain error \(status)"
    }
}

final class MacPasteboardClient: PasteboardClient {
    func snapshot() throws -> Data? {
        NSPasteboard.general.string(forType: .string)?.data(using: .utf8)
    }

    func setString(_ value: String) throws {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    func restore(_ snapshot: Data?) throws {
        NSPasteboard.general.clearContents()
        if let snapshot, let value = String(data: snapshot, encoding: .utf8) {
            NSPasteboard.general.setString(value, forType: .string)
        }
    }
}

final class MacTextInsertionClient: TextInsertionClient {
    func paste() throws {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    func type(_ value: String) throws {
        for scalar in value.unicodeScalars {
            guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
                continue
            }
            var utf16 = Array(String(scalar).utf16)
            keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            keyUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }
}
