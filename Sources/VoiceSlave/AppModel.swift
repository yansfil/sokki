import AppKit
import Foundation
import Speech
import VoiceSlaveCore

/// Persisted settings + shared stores + permission snapshot for the whole app.
@MainActor
final class AppModel: ObservableObject {
    private let store = UserDefaultsSettingsStore()
    var onShortcutChanged: ((String) -> Void)?

    @Published var state: AppSettings {
        didSet {
            store.save(state)
            if oldValue.globalShortcut != state.globalShortcut {
                onShortcutChanged?(state.globalShortcut)
            }
            if oldValue.launchAtLogin != state.launchAtLogin {
                applyLaunchAtLogin()
            }
        }
    }
    @Published var permissions = PermissionSnapshot()
    @Published var apiKeyState: APIKeyState = .absent
    @Published var shortcutRegistrationStatus = ""
    @Published var launchAtLoginStatus = ""

    let history: HistoryStore?
    let vocabulary: VocabularyStore
    let keychain = KeychainAPIKeyStore()
    private let permissionReader = MacPermissionReader()

    init() {
        self.state = store.load()
        let root = try? ApplicationSupport.defaultRoot()
        self.history = root.flatMap { try? HistoryStore(root: $0) }
        let vocabularyURL = (root ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("vocabulary.json")
        self.vocabulary = VocabularyStore(fileURL: vocabularyURL)
        refreshAPIKeyState()
        refreshPermissions()
        applyRetention()
    }

    func refreshPermissions() {
        permissions = permissionReader.snapshot(modelSetupComplete: true)
    }

    func refreshAPIKeyState() {
        let key = (try? keychain.read()) ?? nil
        apiKeyState = (key?.isEmpty == false) ? .present : .absent
    }

    func applyRetention() {
        guard let history else { return }
        _ = try? history.applyRetention(days: state.retentionDays)
    }

    func resetShortcut() {
        state.globalShortcut = AppSettings().globalShortcut
    }

    func loadVocabulary() -> [VocabularyEntry] {
        (try? vocabulary.load()) ?? []
    }

    private func applyLaunchAtLogin() {
        do {
            try LaunchAtLoginController().setEnabled(state.launchAtLogin)
            launchAtLoginStatus = ""
        } catch {
            launchAtLoginStatus = "Couldn't update Login Items: \(error.localizedDescription)"
        }
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

/// Languages offered in pickers. "auto" follows the macOS system locale.
enum DictationLanguage {
    static let options: [(id: String, label: String)] = [
        ("auto", "Automatic (System)"),
        ("ko-KR", "한국어"),
        ("en-US", "English (US)"),
        ("en-GB", "English (UK)"),
        ("ja-JP", "日本語"),
        ("zh-CN", "中文（简体）"),
        ("es-ES", "Español"),
        ("fr-FR", "Français"),
        ("de-DE", "Deutsch")
    ]

    static func label(for id: String) -> String {
        options.first { $0.id == id }?.label ?? id
    }
}
