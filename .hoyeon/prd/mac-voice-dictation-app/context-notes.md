# PRD Context Notes: mac-voice-dictation-app

## Sources Read

- `.hoyeon/intake/mac-voice-dictation-app/prd-handoff.md`
- `.hoyeon/intake/mac-voice-dictation-app/qa-log.md`
- `/Users/hoyeonlee/.codex/skills/prd/SKILL.md`

## Source Summary

The intake defines a personal native Mac dictation utility inspired by Superwhisper and adjacent tools, but scoped to a low-cost local-first MVP.
The clear outcome is a WhisperKit-based native menubar Mac app that toggles recording via global shortcut, transcribes Korean-English/code mixed speech, inserts text at the current cursor, stores local history and user-editable vocabulary, and optionally runs BYO OpenAI cleanup or prompt formatting.

## Repo State

The repository is greenfield.
There is no `.hoyeon/config.json`.
There is no app code, package manifest, Xcode project, or test harness yet.
The PRD must therefore include a task to create the smallest useful native macOS app and test harness.

## Delivery Context

The GitHub repository `yansfil/voice-slave` exists and the local checkout is on branch `codex/mac-voice-dictation-prd`.
The PRD itself does not require opening a pull request.
Delivery mode for implementation is local branch work unless the user separately asks for PR delivery.

## High-Risk Surfaces

- Microphone permission and audio capture.
- Accessibility permission, global shortcuts, clipboard paste, and optional simulated typing.
- Local storage of text and original audio.
- Keychain storage of BYO OpenAI API key.
- Optional OpenAI post-processing with raw transcript only.
- Warm-path latency goals that may require incremental or chunk transcription and model prewarm.

## Decisions To Preserve

- Native Swift/SwiftUI plus AppKit.
- WhisperKit for STT.
- Audio and STT are local-only.
- Cloud post-processing is opt-in, BYO-key, and text-only.
- LLM post-processing sends raw transcript and explicit vocabulary hints only.
- No clipboard, selected text, cursor surroundings, or active app context are sent to LLMs.
- History stores both final text and original audio, but the UI is only a simple recent log in MVP.
- Individual delete and full delete remain required for privacy.
- Launch at Login defaults on.
- Preload model for faster dictation defaults on after setup.
- Personal Vocabulary is user-editable and local-only.
- Translation, file transcription, meeting assistant, custom mode editor, and app-specific triggers are non-goals.
