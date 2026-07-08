import AVFoundation
import Foundation
import Speech

enum SpeechSessionError: LocalizedError {
    case recognizerUnavailable(String)
    case noInputDevice
    case alreadyRunning

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable(let locale):
            return "Speech recognition unavailable for \(locale)"
        case .noInputDevice:
            return "No microphone input device found"
        case .alreadyRunning:
            return "A dictation session is already running"
        }
    }
}

/// Shared state touched from the audio render thread. Kept deliberately tiny:
/// the recognition request and audio file are both safe to feed from a single
/// background thread.
private final class AudioTapBox: @unchecked Sendable {
    let request: SFSpeechAudioBufferRecognitionRequest
    let audioFile: AVAudioFile?

    init(request: SFSpeechAudioBufferRecognitionRequest, audioFile: AVAudioFile?) {
        self.request = request
        self.audioFile = audioFile
    }
}

/// One live dictation: microphone → streaming Apple Speech recognition,
/// with live partial hypotheses, mic level callbacks, and optional
/// audio capture to disk for history.
@MainActor
final class SpeechSession {
    enum Phase {
        case idle
        case running
        case finishing
        case done
    }

    var onPartial: ((String) -> Void)?
    var onLevel: ((Float) -> Void)?
    /// Fired when recognition terminates on its own while recording
    /// (recognizer error, service interruption). The coordinator should
    /// finalize the session.
    var onUnexpectedEnd: ((Error?) -> Void)?

    private(set) var phase: Phase = .idle
    private(set) var latestText = ""
    private(set) var audioFileURL: URL?
    private(set) var usedOnDevice = false

    private let audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var box: AudioTapBox?
    private var finishContinuation: CheckedContinuation<Void, Never>?
    private var recognitionEnded = false

    static func locale(for identifier: String) -> Locale {
        identifier == "auto" ? Locale.current : Locale(identifier: identifier)
    }

    func start(
        localeIdentifier: String,
        preferOnDevice: Bool,
        contextualStrings: [String],
        audioFileURL: URL?
    ) throws {
        guard phase == .idle else { throw SpeechSessionError.alreadyRunning }
        let locale = Self.locale(for: localeIdentifier)
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw SpeechSessionError.recognizerUnavailable(locale.identifier)
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.addsPunctuation = true
        if preferOnDevice && recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
            usedOnDevice = true
        }
        if !contextualStrings.isEmpty {
            request.contextualStrings = contextualStrings
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw SpeechSessionError.noInputDevice
        }

        var audioFile: AVAudioFile?
        if let audioFileURL {
            audioFile = try? AVAudioFile(forWriting: audioFileURL, settings: format.settings)
            if audioFile != nil {
                self.audioFileURL = audioFileURL
            }
        }

        let box = AudioTapBox(request: request, audioFile: audioFile)
        self.box = box
        let levelSink: @Sendable (Float) -> Void = { [weak self] level in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.onLevel?(level)
                }
            }
        }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            box.request.append(buffer)
            try? box.audioFile?.write(from: buffer)
            levelSink(Self.normalizedLevel(of: buffer))
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            self.box = nil
            throw error
        }

        phase = .running
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.handleRecognition(result: result, error: error)
                }
            }
        }
    }

    /// Stops the microphone, finalizes recognition, and returns the best
    /// transcript. Waits briefly for the recognizer's final result, falling
    /// back to the last partial hypothesis.
    func finish(timeout: TimeInterval = 3.0) async -> String {
        guard phase == .running else { return latestText }
        phase = .finishing
        stopAudio()
        box?.request.endAudio()

        if !recognitionEnded {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                finishContinuation = continuation
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    self?.completeFinish()
                }
            }
        }

        phase = .done
        recognitionTask = nil
        box = nil
        return latestText
    }

    func cancel() {
        stopAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        box = nil
        phase = .done
        completeFinish()
    }

    private func handleRecognition(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            latestText = result.bestTranscription.formattedString
            onPartial?(latestText)
            if result.isFinal {
                recognitionEnded = true
                completeFinish()
            }
        }
        if let error {
            recognitionEnded = true
            if phase == .running {
                onUnexpectedEnd?(error)
            }
            completeFinish()
        }
    }

    private func stopAudio() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
    }

    private func completeFinish() {
        finishContinuation?.resume()
        finishContinuation = nil
    }

    private nonisolated static func normalizedLevel(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        let frames = Int(buffer.frameLength)
        for index in 0..<frames {
            let sample = channelData[index]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frames))
        guard rms > 0 else { return 0 }
        let db = 20 * log10(rms)
        // Map -50dB...0dB → 0...1
        return min(1, max(0, (db + 50) / 50))
    }
}

/// Speech/microphone permission helpers.
enum SpeechPermissions {
    static func requestMicrophone() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    static func requestSpeechRecognition() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}
