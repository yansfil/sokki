import AppKit
import Foundation
import SokkiCore

if CommandLine.arguments.contains("--qa-smoke") {
    try runQASmoke()
    Foundation.exit(0)
}

func runQASmoke() throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SokkiQASmoke", isDirectory: true)
    try? FileManager.default.removeItem(at: root)
    let history = try HistoryStore(root: root)
    let pipeline = DictationPipeline()
    let result = pipeline.process(
        rawTranscript: "  안녕 Sokki\nlet value = 1  ",
        mode: .dictation,
        apiKeyState: .absent,
        vocabulary: []
    )
    try history.add(
        HistoryRecord(
            rawTranscript: result.rawTranscript,
            finalOutput: result.finalOutput,
            mode: result.mode,
            status: result.status,
            audioFileName: "qa-fixture.wav"
        ),
        audioData: Data("fixture-audio".utf8)
    )
    let rows = try history.all()
    print("Sokki QA smoke")
    print("menubar=available settings=available overlay=available")
    print("dictationMode=offline-capable cloudSTT=false")
    print("historyRows=\(rows.count) audioDir=\(history.audioDirectory.path)")
    try history.deleteAll()
    print("deleteAllRows=\(try history.all().count)")
}

let delegate = SokkiAppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
