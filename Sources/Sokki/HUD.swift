import AppKit
import SwiftUI
import SokkiCore

/// Floating recording pill at the top-center of the active screen.
/// Uses a non-activating panel so keyboard focus stays in the target app —
/// required for paste-at-cursor to land in the right place.
@MainActor
final class HUDController {
    private weak var coordinator: RecordingCoordinator?
    private var panel: NSPanel?

    private static let panelSize = NSSize(width: 520, height: 130)

    init(coordinator: RecordingCoordinator) {
        self.coordinator = coordinator
    }

    func show() {
        guard let coordinator else { return }
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(origin: .zero, size: Self.panelSize),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.isMovableByWindowBackground = false
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = true
            panel.isFloatingPanel = true
            panel.contentView = NSHostingView(rootView: HUDView(coordinator: coordinator))
            self.panel = panel
        }
        position()
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func position() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let x = frame.midX - Self.panelSize.width / 2
        // Top-center, just below the menu bar (visibleFrame already excludes it).
        let y = frame.maxY - Self.panelSize.height - 16
        panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: Self.panelSize), display: true)
    }
}

struct HUDView: View {
    @ObservedObject var coordinator: RecordingCoordinator

    var body: some View {
        VStack {
            pill
                .animation(.easeOut(duration: 0.18), value: coordinator.phase)
                .animation(.easeOut(duration: 0.18), value: coordinator.partialText.isEmpty)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var pill: some View {
        VStack(spacing: 8) {
            switch coordinator.phase {
            case .recording:
                recordingRow
                if !coordinator.partialText.isEmpty {
                    transcriptLine(coordinator.partialText, dimmed: false)
                }
            case .transcribing:
                transcribingRow
                if !coordinator.partialText.isEmpty {
                    transcriptLine(coordinator.partialText, dimmed: true)
                }
            case .notice(let kind, let message):
                noticeRow(kind: kind, message: message)
            case .idle:
                EmptyView()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(minWidth: 320, maxWidth: 500)
        .fixedSize(horizontal: true, vertical: true)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.black.opacity(0.72))
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .shadow(color: .black.opacity(0.35), radius: 18, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .colorScheme(.dark)
    }

    private var recordingRow: some View {
        HStack(spacing: 12) {
            PulsingDot()
            Text(timeString(coordinator.elapsed))
                .font(.system(.callout, design: .monospaced).weight(.medium))
                .foregroundStyle(.white)
            LevelWaveform(levels: coordinator.levels)
                .frame(width: 170, height: 26)
            Text(coordinator.model.state.selectedMode.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(.white.opacity(0.14)))
            Text("esc")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.35), lineWidth: 1))
            Text("취소")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
            Button {
                Task { await coordinator.stopAndInsert() }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white, .green)
            }
            .buttonStyle(.plain)
            .help("Stop and insert")
        }
    }

    private var transcribingRow: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(.white)
            Text("Transcribing…")
                .font(.callout.weight(.medium))
                .foregroundStyle(.white)
        }
    }

    private func noticeRow(kind: RecordingCoordinator.NoticeKind, message: String) -> some View {
        HStack(spacing: 10) {
            switch kind {
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white, .green)
            case .info:
                Image(systemName: "doc.on.clipboard.fill")
                    .foregroundStyle(.white, .blue)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.black, .yellow)
            }
            Text(message)
                .font(.callout.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(2)
        }
    }

    private func transcriptLine(_ text: String, dimmed: Bool) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.white.opacity(dimmed ? 0.45 : 0.75))
            .lineLimit(1)
            .truncationMode(.head)
            .frame(maxWidth: 460)
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct PulsingDot: View {
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 11, height: 11)
            .scaleEffect(pulsing ? 1.0 : 0.72)
            .opacity(pulsing ? 1.0 : 0.6)
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
    }
}

struct LevelWaveform: View {
    var levels: [Float]

    var body: some View {
        GeometryReader { proxy in
            let count = max(levels.count, 1)
            let barWidth = max(2, proxy.size.width / CGFloat(count) - 2)
            HStack(alignment: .center, spacing: 2) {
                ForEach(levels.indices, id: \.self) { index in
                    let level = CGFloat(levels[index])
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.white.opacity(0.35 + 0.6 * level))
                        .frame(
                            width: barWidth,
                            height: max(3, proxy.size.height * (0.15 + 0.85 * level))
                        )
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }
}
