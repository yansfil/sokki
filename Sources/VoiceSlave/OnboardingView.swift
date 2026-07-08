import AppKit
import SwiftUI
import VoiceSlaveCore

/// First-run window: grant permissions, learn the shortcut, try a dictation
/// into the built-in test field — all on one screen.
struct OnboardingView: View {
    @ObservedObject var model: AppModel
    var onDone: () -> Void

    @State private var testText = ""

    private var shortcutDisplay: String {
        KeyboardShortcut.parse(model.state.globalShortcut)?.compactDisplay ?? model.state.globalShortcut
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white, .tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("VoiceSlave")
                        .font(.title.bold())
                    Text("Press \(shortcutDisplay) anywhere, speak, press it again — your words appear at the cursor.")
                        .foregroundStyle(.secondary)
                }
            }

            GroupBox("1. Grant permissions") {
                Form {
                    PermissionsSection(model: model)
                }
                .formStyle(.columns)
                .padding(6)
            }

            GroupBox("2. Try it here") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Click into the field below, press \(shortcutDisplay), say something, then press \(shortcutDisplay) again. Hold-to-talk also works: keep it pressed while speaking and release.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $testText)
                        .font(.body)
                        .frame(height: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(.quaternary, lineWidth: 1)
                        )
                }
                .padding(6)
            }

            HStack {
                Text(model.permissions.canDictate
                     ? "You're ready to dictate."
                     : "Microphone + Speech Recognition are required to start.")
                    .font(.caption)
                    .foregroundStyle(model.permissions.canDictate ? .green : .secondary)
                Spacer()
                Button("Start using VoiceSlave") {
                    model.state.hasCompletedOnboarding = true
                    onDone()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 560)
    }
}
