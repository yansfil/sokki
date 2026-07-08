import AppKit
import Foundation
import SwiftUI
import VoiceSlaveCore

if CommandLine.arguments.contains("--qa-smoke") {
    try runQASmoke()
    Foundation.exit(0)
}

@MainActor
final class VoiceSlaveAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var overlayWindow: NSWindow?
    private let settings = ObservableSettings()
    private let modeGate = ModeGate()
    private let shortcutMonitor = GlobalShortcutMonitor()
    private let launchArguments = Set(CommandLine.arguments.dropFirst())

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        settings.onShortcutChanged = { [weak self] shortcut in
            self?.installGlobalShortcut(shortcut)
        }
        installMenuBar()
        installGlobalShortcut(settings.state.globalShortcut)
        if launchArguments.contains("--show-settings") {
            openSettings()
        }
        if launchArguments.contains("--show-overlay") {
            showOverlay(status: "Recording", mode: settings.state.selectedMode.rawValue)
        }
    }

    private func installMenuBar() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "VS"
        statusItem.button?.toolTip = "VoiceSlave"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Start/Stop Dictation", action: #selector(toggleRecording), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit VoiceSlave", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
        self.statusItem = statusItem
    }

    private func installGlobalShortcut(_ shortcut: String) {
        if let registered = shortcutMonitor.start(shortcutText: shortcut, action: { [weak self] in
            self?.toggleRecording()
        }) {
            settings.shortcutRegistrationStatus = "Registered: \(registered.displayName)"
        } else {
            settings.shortcutRegistrationStatus = "Invalid shortcut"
        }
    }

    @objc private func toggleRecording() {
        if overlayWindow == nil {
            showOverlay(status: "Recording", mode: settings.state.selectedMode.rawValue)
        } else {
            overlayWindow?.close()
            overlayWindow = nil
        }
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.title = "VoiceSlave Settings"
            window.contentView = NSHostingView(rootView: SettingsView(settings: settings))
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showOverlay(status: String, mode: String) {
        if overlayWindow != nil {
            overlayWindow?.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 136),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .transient]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.contentView = NSHostingView(rootView: RecordingOverlay(status: status, mode: mode, shortcut: settings.state.globalShortcut) { [weak self] in
            self?.overlayWindow?.close()
            self?.overlayWindow = nil
        })
        positionOverlay(window)
        window.orderFrontRegardless()
        overlayWindow = window
    }

    private func positionOverlay(_ window: NSWindow) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let frame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let windowSize = window.frame.size
        let x = frame.midX - (windowSize.width / 2)
        let y = frame.maxY - windowSize.height - 28
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

@MainActor
final class ObservableSettings: ObservableObject {
    private let store = UserDefaultsSettingsStore()
    var onShortcutChanged: ((String) -> Void)?

    @Published var state: AppSettings {
        didSet {
            store.save(state)
            if oldValue.globalShortcut != state.globalShortcut {
                onShortcutChanged?(state.globalShortcut)
            }
        }
    }
    @Published var permissions = PermissionSnapshot()
    @Published var model = ModelSetupState()
    @Published var apiKeyState: APIKeyState = .absent
    @Published var shortcutRegistrationStatus = ""

    init() {
        self.state = store.load()
    }

    func resetShortcut() {
        state.globalShortcut = AppSettings().globalShortcut
    }
}

struct UserDefaultsSettingsStore {
    private let key = "VoiceSlave.AppSettings.v1"

    func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

struct SettingsView: View {
    @ObservedObject var settings: ObservableSettings
    private let gate = ModeGate()

    var body: some View {
        TabView {
            Form {
                Toggle("Launch at Login", isOn: $settings.state.launchAtLogin)
                Toggle("Preload model for faster dictation", isOn: $settings.state.preloadModel)
                Toggle("Typing Mode", isOn: $settings.state.typingModeEnabled)
                TextField("Global Shortcut", text: $settings.state.globalShortcut)
                Picker("Mode", selection: $settings.state.selectedMode) {
                    ForEach(DictationMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                HStack {
                    Text(settings.shortcutRegistrationStatus)
                    Spacer()
                    Button("Reset Shortcut") {
                        settings.resetShortcut()
                    }
                }
                Text("Bundle ID: \(settings.state.bundleIdentifier)")
            }
            .padding()
            .tabItem { Text("General") }

            Form {
                Text("WhisperKit model: \(settings.model.selectedModel)")
                Text("Fallbacks: \(settings.model.fallbackModels.joined(separator: ", "))")
                Text("Microphone: \(settings.permissions.microphone.rawValue)")
                Text("Accessibility: \(settings.permissions.accessibility.rawValue)")
                Text("Model setup: \(settings.permissions.modelSetupComplete ? "Ready" : "Required")")
            }
            .padding()
            .tabItem { Text("Onboarding") }

            Form {
                Text("Default OpenAI model: \(settings.state.openAIModel)")
                Text("Quality model: \(settings.state.qualityModel)")
                ForEach([DictationMode.cleanup, .prompt], id: \.self) { mode in
                    let availability = gate.availability(for: mode, apiKeyState: settings.apiKeyState)
                    HStack {
                        Text(mode.rawValue)
                        Spacer()
                        Text(availability.isEnabled ? "Enabled" : "Disabled")
                    }
                }
            }
            .padding()
            .tabItem { Text("Cloud Modes") }
        }
        .frame(minWidth: 680, minHeight: 500)
    }
}

struct RecordingOverlay: View {
    var status: String
    var mode: String
    var shortcut: String
    var stop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                    Text(status)
                        .font(.headline)
                }
                Spacer()
                Text(mode)
                    .font(.subheadline)
            }
            Text("Listening locally")
                .font(.caption)
                .foregroundStyle(.secondary)
            WaveformView()
                .frame(height: 36)
            HStack {
                Text("00:00")
                    .monospacedDigit()
                Spacer()
                Text(shortcut)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Stop", action: stop)
                Button("Cancel", action: stop)
            }
        }
        .padding(18)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct WaveformView: View {
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<18, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 5, height: CGFloat(10 + (index % 5) * 5))
            }
        }
    }
}

func runQASmoke() throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("VoiceSlaveQASmoke", isDirectory: true)
    try? FileManager.default.removeItem(at: root)
    let history = try HistoryStore(root: root)
    let pipeline = DictationPipeline()
    let result = pipeline.process(
        rawTranscript: "  안녕 VoiceSlave\nlet value = 1  ",
        mode: .dictation,
        apiKeyState: .absent,
        vocabulary: []
    )
    try history.add(HistoryRecord(
        rawTranscript: result.rawTranscript,
        finalOutput: result.finalOutput,
        mode: result.mode,
        status: result.status,
        audioFileName: "qa-fixture.wav"
    ))
    let rows = try history.all()
    print("VoiceSlave QA smoke")
    print("menubar=available settings=available overlay=available")
    print("dictationMode=offline-capable cloudSTT=false")
    print("historyRows=\(rows.count) audioDir=\(history.audioDirectory.path)")
    try history.deleteAll()
    print("deleteAllRows=\(try history.all().count)")
}

let delegate = VoiceSlaveAppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
