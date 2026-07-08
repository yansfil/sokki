---
topic: "mac-voice-dictation-app"
status: "ready"
human_approval: "pending"
source_intake: ".hoyeon/intake/mac-voice-dictation-app/prd-handoff.md"
source_clarity: "none"
created_at: "2026-07-08"
updated_at: "2026-07-08"
---

# PRD: mac-voice-dictation-app

## 1. Summary

Build `VoiceSlave`, a personal native macOS menubar dictation utility.
The app uses WhisperKit for local STT, starts and stops recording with a configurable global shortcut, quickly inserts Korean-English/code mixed speech at the current cursor, stores a simple local history with audio and text, and offers user-editable Personal Vocabulary.
The app can optionally run `Cleanup` and `Prompt` post-processing through a BYO OpenAI API key stored in Keychain.
Audio and STT remain local-only.
Cloud post-processing is opt-in, text-only, and must not include clipboard, selected text, cursor surroundings, or active app context.

Approval checklist:

- Approve MVP scope and non-goals in sections 3, 6, and 7.
- Approve native Swift/SwiftUI plus AppKit, WhisperKit, local storage, Keychain, and optional OpenAI boundaries in section 5.
- Approve privacy-sensitive choices for local audio history, clipboard paste/restore, and raw-transcript-only LLM post-processing in sections 5, 10, and 11.
- Approve warm-path latency targets and required verification modes in sections 7 and 9.
- Approve delivery mode as local branch work on `codex/mac-voice-dictation-prd`, with no PR creation required by this PRD unless separately requested, in sections 4 and 12.
- Approve that implementation is blocked until `human_approval` is explicitly set to `approved`.

## 2. Problem, Goal, And Users

Superwhisper and adjacent dictation tools are useful but feel too expensive for the intended personal workflow.
The primary user is 호연 using a local Mac utility for fast daily dictation into existing apps.
The goal is to replace subscription dictation for personal use with a local-first native app that feels fast, private, and keyboard-centric.
The app should preserve future distribution options architecturally, but the MVP is not a public paid product.

Success means the user can press one shortcut, speak naturally in Korean-English/code mixed language, stop recording, and see useful text inserted into the active app with minimal delay.
Success also means the user can trust that audio and local transcription do not leave the Mac, and that optional OpenAI post-processing has an explicit BYO-key boundary.

## 3. Scope And Non-Goals

In scope:

- Configurable global shortcut for toggle start and toggle stop.
- Menubar-only macOS utility with Settings window opened only when needed.
- Launch at Login default on.
- First-run onboarding for Microphone and Accessibility permissions.
- First-run WhisperKit model setup with download progress, retry, offline/failure state, and fallback model selection.
- WhisperKit local transcription with a default large-v3 turbo class preset for the local M4 Pro development machine and a structure that allows lower-spec fallback presets.
- Background model prewarm after setup, with `Preload model for faster dictation` default on.
- Compact sound-reactive always-on-top overlay with waveform, timer, current mode, status, stop, cancel, and mode switch.
- Clipboard paste insertion with best-effort original clipboard restore.
- Optional off-by-default `Typing Mode` for paste-hostile apps or VDI environments.
- Built-in modes `Dictation`, `Cleanup`, and `Prompt`.
- OpenAI Keychain setup for BYO-key post-processing.
- `gpt-5.4-nano` as default OpenAI model, `gpt-5.4-mini` as optional quality upshift/fallback, and manual model override in advanced settings.
- Simple recent local history that stores raw transcript, final output, mode, status, timestamp, and original audio reference.
- Individual delete and full delete for history.
- Optional 7/30/90-day auto-delete retention.
- User-editable local-only Personal Vocabulary with optional `spoken hint`, `preferred spelling`, and `category`.
- Korean-English/code mixed dictation that preserves original language mixing and does not translate.
- Real Mac end-to-end verification and warm-path latency benchmarks.

Non-goals:

- No cloud STT in MVP.
- No sending audio to OpenAI or other remote providers.
- No sending clipboard, selected text, cursor surroundings, or active app context to LLMs.
- No custom mode editor in MVP.
- No mode-specific shortcuts in MVP.
- No app-specific mode triggers in MVP.
- No file transcription in MVP.
- No meeting assistant in MVP.
- No history search, tags, export, audio replay, copy buttons, or LLM retry action surface in MVP.
- No automatic vocabulary learning in MVP.
- No translation feature in MVP.
- No encrypted history storage in MVP.
- No public distribution, payment, licensing, crash reporting, telemetry, or updater requirement in MVP.

## 4. Pre-Work And Required Decisions

### 4.1 Pre-Work Before Implementation

- Confirm whether `VoiceSlave` is acceptable as the app name and Xcode scheme name, or replace it before scaffolding.
- Choose a bundle identifier before creating the Xcode project.
- Re-verify the exact WhisperKit model identifier and download path during implementation.
- Re-verify OpenAI model availability and pricing before hardcoding defaults.
- Confirm that the local machine has Xcode and the macOS SDK required for native app development.
- Confirm whether Developer ID signing and notarization are needed before sharing the app beyond the local machine.

### 4.2 Human Decisions Before PRD Approval

- Approve the MVP scope and non-goals.
- Approve storing original audio locally in Application Support with backup exclusion, deletion UX, and no MVP encryption.
- Approve native Swift/SwiftUI plus AppKit as the app architecture.
- Approve WhisperKit as the STT runtime.
- Approve raw-transcript-only BYO OpenAI post-processing and Keychain secret storage.
- Approve warm-path latency targets as development targets, not hard guarantees.
- Approve delivery mode as local branch work without automatic PR creation.

### 4.3 Decision Traceability For Fidelity Review

- Personal local Mac utility, not public SaaS: represented by R1, R2, non-goals, and guardrails.
- Native Swift/SwiftUI plus AppKit: represented by R1, R2, T1, V1, and section 5.
- WhisperKit local STT: represented by R3, R4, AC3, AC4, T2, V2, and V3.
- Audio/STT local-only: represented by R8, AC10, V7, non-goals, risks, and guardrails.
- BYO OpenAI post-processing only: represented by R6, AC6, AC7, T6, V4, V8, and non-goals.
- `gpt-5.4-nano` default with `gpt-5.4-mini` upshift: represented by R6 and AC6.
- Clipboard paste with restore: represented by R5, AC5, T5, V2, and V3.
- Typing Mode fallback default off: represented by R5, AC5, T5, V2, V3, and non-goals.
- History simple recent log only: represented by R7, AC8, T7, V2, V3, and non-goals.
- History stores text and original audio: represented by R7, R8, AC8, AC9, T7, V2, and V7.
- Launch at Login default on and prewarm default on: represented by R1, R3, AC1, AC3, T1, T2, V1, and V3.
- Korean-English/code mixed dictation and Personal Vocabulary: represented by R4, AC4, T4, V2, V3, and V5.
- Warm-path latency targets: represented by R9, AC12, T11, and V6.
- End-to-end Mac verification: represented by R10, AC13, T12, V1-V8, and human verification.
- Rejected or deferred custom mode editor, meeting assistant, file transcription, app-specific triggers, export, and automatic vocabulary learning: represented by non-goals and guardrails.

## 5. Major Technical Structure Changes

Create a new native macOS app codebase.
Use Swift/SwiftUI for settings and core UI, with AppKit integration for menubar lifecycle, global hotkey, Accessibility behavior, overlay windows, clipboard paste, and optional simulated typing.

Create a transcription boundary.
WhisperKit is the MVP implementation, but the code should keep transcription behind a `TranscriptionEngine` style boundary so fallback models and future engines do not leak through the UI.

Create a post-processing boundary.
Local deterministic cleanup and optional OpenAI post-processing should sit behind a `PostProcessor` style boundary.
OpenAI requests must only receive raw transcript and explicit vocabulary hints when the user chooses a cloud mode.

Create an insertion boundary.
Clipboard paste and optional Typing Mode should sit behind an `InsertionService` style boundary.
Clipboard restore must be best-effort and must not cause insertion failure when restore fails.

Create a local persistence boundary.
Store SQLite metadata and audio files under Application Support.
Exclude history storage from iCloud backup.
Implement retention cleanup, individual delete, full delete, and history status fields.

Create a secret boundary.
Store OpenAI API keys in macOS Keychain.
Allow `OPENAI_API_KEY` only as a debug/dev fallback.
Do not parse `~/.zshrc` from the GUI app.

Create a model setup and prewarm boundary.
First-run setup downloads the default WhisperKit model with progress, retry, offline/failure state, and fallback selection.
After setup, prewarm runs in the background and can be disabled in Settings.

Create timing instrumentation.
Record timing segments for cold start, model load, transcription, post-processing, paste, and total stop-to-paste latency.

## 6. Requirements

- R1. The app must be a menubar-only native macOS utility with Settings, Launch at Login default on, and a future-compatible local distribution structure.
- R2. The app must provide first-run onboarding for required permissions and WhisperKit model setup.
- R3. The app must support a configurable global shortcut that toggles recording start and stop, with model prewarm supporting low-latency warm-path dictation.
- R4. The app must transcribe Korean-English/code mixed speech locally with WhisperKit, preserve language mixing, and support user-editable Personal Vocabulary.
- R5. The app must insert transcription results at the current cursor through clipboard paste with best-effort restore, plus optional off-by-default Typing Mode.
- R6. The app must provide built-in `Dictation`, `Cleanup`, and `Prompt` modes with raw-transcript-only BYO OpenAI post-processing for cloud modes.
- R7. The app must store simple recent local history with text, audio reference, mode, status, timestamp, retention, and deletion controls.
- R8. The app must enforce privacy and sensitive-data boundaries for audio, transcript, clipboard, selected text, active app context, API keys, and local storage.
- R9. The app must expose timing instrumentation and target aggressive warm-path stop-to-paste latency.
- R10. The implementation must provide enough automated and real Mac verification to prove the main workflow, security boundaries, and fallback behavior.

## 7. Acceptance Criteria

- AC1. Covers R1. The built app runs as a menubar-only app, shows no normal Dock-first workflow by default, opens Settings on demand, and enables Launch at Login by default with a user setting to disable it.
- AC2. Covers R2. First-run onboarding detects Microphone and Accessibility status, opens relevant System Settings, offers test dictation, and blocks normal dictation until required permissions and model setup are complete enough to proceed.
- AC3. Covers R2 and R3. First-run model setup downloads the default WhisperKit large-v3 turbo class model with progress, retry, offline/failure state, and fallback model selection, then prewarms the model in the background without blocking login.
- AC4. Covers R3 and R4. The global shortcut toggles recording start and stop, the overlay appears during recording, and a Korean-English/code mixed fixture is transcribed locally without translation.
- AC5. Covers R5. Stop-to-insert uses clipboard paste, restores the prior clipboard best-effort, treats restore failure separately from insertion failure, and supports manually enabled Typing Mode for paste-hostile targets.
- AC6. Covers R6. `Dictation` works without OpenAI and performs only local deterministic cleanup before insertion.
- AC7. Covers R6 and R8. `Cleanup` and `Prompt` are visible-but-disabled without an API key, use Keychain for the key when enabled, default to `gpt-5.4-nano`, allow `gpt-5.4-mini` upshift/manual override, and send only raw transcript plus allowed vocabulary hints.
- AC8. Covers R6. If OpenAI post-processing fails or times out, the app inserts the raw transcript, shows a brief failed post-processing state, and records the failure status in history.
- AC9. Covers R7. History stores raw transcript, final output, mode, status, timestamp, and an original audio file reference in Application Support using SQLite metadata plus audio files.
- AC10. Covers R7 and R8. History supports individual delete, full delete, backup exclusion, default indefinite retention, and optional 7/30/90-day auto-delete.
- AC11. Covers R4. Settings lets the user add, edit, and delete local-only Personal Vocabulary entries with optional `spoken hint`, `preferred spelling`, and `category`.
- AC12. Covers R8. No audio leaves the Mac, no cloud STT exists, and OpenAI post-processing never sends clipboard contents, selected text, cursor surroundings, or active app context.
- AC13. Covers R9. Warm-path latency benchmarks report `Dictation` stop-to-paste p50 <= 1s and p95 <= 2s, and `Cleanup`/`Prompt` stop-to-paste p50 <= 2s and p95 <= 4s, while cold start and first download are measured separately.
- AC14. Covers R10. Automated tests cover local cleanup, mode gating, API key state, vocabulary persistence, history deletion/retention logic, clipboard restore logic, and timing metric calculation.
- AC15. Covers R10. Real Mac app verification proves permission onboarding, shortcut record/stop, overlay controls, TextEdit or Notes insertion, network-off `Dictation`, no-key disabled modes, BYO-key cloud modes when credentials are available, and deletion UX.

## 8. PRD-Level Tasks

- T1. Scaffold the native macOS menubar app, Settings surface, Launch at Login default, and minimal build/test harness. Covers R1, AC1.
- T2. Implement first-run permissions onboarding, WhisperKit model download/setup, fallback selection, and background prewarm. Covers R2, R3, AC2, AC3.
- T3. Implement global shortcut recording toggle, audio capture pipeline, and compact interactive overlay. Covers R3, AC4.
- T4. Implement WhisperKit transcription, Korean-English/code mixed handling, deterministic cleanup, and user-editable Personal Vocabulary. Covers R4, AC4, AC11.
- T5. Implement insertion through clipboard paste/restore and optional Typing Mode. Covers R5, AC5.
- T6. Implement built-in modes, Keychain OpenAI setup, no-key disabled mode UI, OpenAI model settings, and raw-transcript-only post-processing. Covers R6, R8, AC6, AC7, AC8, AC12.
- T7. Implement local history storage, audio file persistence, backup exclusion, retention, status tracking, individual delete, and full delete. Covers R7, R8, AC9, AC10.
- T8. Implement privacy guardrails and tests that prevent unapproved context from entering OpenAI requests. Covers R8, AC7, AC12.
- T9. Implement timing instrumentation and warm-path latency benchmark tooling. Covers R9, AC13.
- T10. Add automated regression tests for local logic, storage, mode gating, vocabulary, privacy request construction, insertion service behavior, and metrics. Covers R10, AC14.
- T11. Run and document real Mac end-to-end verification, including offline `Dictation` and optional BYO-key smoke proof. Covers R10, AC15.
- T12. Produce the implementation result report with task status, R/AC/V coverage, verification evidence, deviations, and remaining human review. Covers R10, AC14, AC15.

## 9. Verification Contract

### 9.1 Test Mode Contract

| Mode | Required For Done | Covers | Human Decision |
| --- | --- | --- | --- |
| build/static | yes | native app build, project health, compile-time integration | none |
| automated behavior | yes | local logic, storage, privacy boundaries, mode gating, metrics, and regression tests | none |
| desktop app QA | yes | real Mac permission, shortcut, overlay, insertion, offline dictation, and deletion flows | final UX judgment remains human |
| live external API | no/blockable | optional BYO OpenAI smoke proof with safe low-cost request | credentials and spend approval required |

### 9.2 Required Agent Verification

| ID | Mode | Covers | Method | Artifact | Pass Criteria | Environment | Required For Done | Can Be Blocked | Safe Probe | Side Effect | Sensitive Data Policy |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| V1 | build/static | R1-R10, AC1-AC15, T1-T12 | `bash -lc "xcodebuild -scheme VoiceSlave -destination 'platform=macOS' build"` or the equivalent repo-defined build command after scaffold | command-log | Build exits 0 and no compile-time integration errors remain. | local macOS shell | yes | no | none | local build artifacts only | no secrets in logs |
| V2 | automated behavior | R4-R10, AC5-AC14, T4-T10 | `bash -lc "xcodebuild test -scheme VoiceSlave -destination 'platform=macOS'"` or the equivalent repo-defined test command after scaffold | command-log | Automated tests cover the stated regression risks and exit 0. | local macOS shell | yes | no | none | local test data only | fixture audio/text only, no real secrets |
| V3 | desktop app QA | R1-R7, R9-R10, AC1-AC11, AC13, AC15, T1-T7, T9, T11 | Run the built app locally and exercise onboarding, shortcut record/stop, overlay controls, TextEdit or Notes insertion, clipboard restore, Typing Mode, history delete, and network-off `Dictation`. | screenshot, log, file | Evidence shows the real Mac user flow works and any deviations are recorded. | local macOS desktop | yes | no | none | local app state, local history test data | use non-sensitive test speech and delete created history |
| V4 | automated behavior | R6, R8, AC7, AC8, AC12, T6, T8 | Test OpenAI request construction, API-key state transitions, no-key disabled modes, timeout/failure fallback, and disallowed context exclusion with mocks or fakes. | command-log | Tests prove only raw transcript plus allowed vocabulary hints are sent and fallback inserts raw transcript on failure. | local macOS shell | yes | no | none | local mocked calls only | no real clipboard, selected text, active app context, or API key in test logs |
| V5 | automated behavior | R4, R7-R8, AC9-AC12, AC14, T4, T7, T8, T10 | Test Personal Vocabulary persistence, history retention/deletion, backup exclusion marker behavior where feasible, and local-only data boundaries. | command-log | Tests exit 0 and prove persistence and deletion behavior without production data. | local macOS shell | yes | no | none | local test database and temporary audio fixtures | fixture data only |
| V6 | automated behavior | R9-R10, AC13-AC15, T9, T11 | `bash -lc "./scripts/measure-warm-latency.sh"` or the equivalent repo-defined latency benchmark command created during implementation | command-log, file | Report includes p50/p95 for `Dictation`, `Cleanup`, and `Prompt`, and separately reports cold start or first download measurements. | local macOS shell | yes | no | none | local benchmark audio/text fixtures | fixture data only |
| V7 | desktop app QA | R8, AC10, AC12, AC15, T7, T8, T11 | Inspect app behavior and local files after delete flows and network-off `Dictation`; record screenshots/logs/file evidence. | screenshot, log, file | Evidence shows audio/STT remain local, delete removes intended history, and network-off `Dictation` still works. | local macOS desktop | yes | no | none | local file creation/deletion only | no personal audio, use test phrases and remove generated files |
| V8 | live external API | R6, R8, AC7-AC8, AC15, T6, T11 | If `OPENAI_API_KEY` or a test Keychain key is available, run one low-cost BYO-key `Cleanup` or `Prompt` smoke test using non-sensitive text. | api-log, screenshot, log | Cloud mode succeeds with expected formatted output, or if unavailable the blocker is recorded and mocked verification V4 remains the required proof. | local macOS desktop with approved key | no | yes | one non-sensitive low-token request against the configured model | may create one OpenAI API request and small cost | redact token and request IDs, use non-sensitive fixture text only |

### 9.3 Human Verification

- HV1. Review and approve the PRD scope, non-goals, technical structure, and privacy boundaries before implementation begins.
- HV2. After implementation, judge whether overlay motion, menu structure, settings copy, and overall Mac utility feel are acceptable.
- HV3. Decide whether Developer ID signing, notarization, DMG packaging, PR creation, or wider distribution is needed after the local MVP works.
- HV4. Decide whether the app name `VoiceSlave` and bundle identifier are acceptable before finalizing project metadata.

## 10. Risks And Open Decisions

- Original audio is stored locally in plaintext Application Support for MVP, so deletion, backup exclusion, and retention must be correct.
- History encryption is deferred and must not be silently introduced or ignored as a hidden promise.
- WhisperKit large-v3 turbo class latency may miss the aggressive target on cold start or lower-spec hardware, so benchmarks must separate warm path, cold start, and first download.
- Incremental or chunk transcription may require adjustment based on WhisperKit capabilities, but the product target remains near-immediate stop-to-paste behavior.
- Clipboard restore is best-effort and may not fully restore large, file, image, or rich clipboard payloads.
- Typing Mode requires Accessibility permission and may be slow for long text.
- OpenAI model names and pricing may drift, so implementation must re-verify current model availability before hardcoding defaults.
- BYO-key live verification can be blocked by missing credentials or spend concerns; mocked automated tests remain required.
- The exact WhisperKit model identifier and download source remain implementation-time confirmations, not product ambiguity.
- The final app name and bundle identifier remain human decisions before app metadata is locked.

## 11. Implementation Guardrails

- Do not add cloud STT.
- Do not send audio to any remote provider.
- Do not send clipboard contents, selected text, cursor surroundings, active app context, or app name to OpenAI in MVP.
- Do not add a custom mode editor without approval.
- Do not add meeting assistant, file transcription, export, or advanced history action features without approval.
- Do not add telemetry, crash reporting, billing, licensing, updater, or public distribution flows without approval.
- Do not make `Cleanup` or `Prompt` silently fall back to raw transcript when no API key exists.
- Do not parse `~/.zshrc` from the GUI app for secrets.
- Do not store OpenAI API keys outside Keychain except approved debug/dev environment fallback.
- Do not mark latency targets met without reporting p50/p95 and separating cold start from warm path.
- Do not remove local history deletion controls or backup exclusion.
- Do not expand delivery into a PR or CI workflow unless the user explicitly asks.

## 12. Implementation Result Report Contract

The implementing agent must report:

- Status: `Done`, `Partially Done`, or `Blocked`.
- User-visible changes in the native Mac app.
- Major changed modules, app surfaces, services, storage shapes, and external boundaries.
- Whether the approved native Swift/SwiftUI plus AppKit, WhisperKit, local storage, Keychain, and OpenAI boundaries were followed.
- Task completion status for T1-T12.
- Requirement and acceptance coverage for R1-R10 and AC1-AC15.
- Verification evidence for V1-V8, including command logs, screenshots, local file evidence, latency benchmark reports, and any blocked live external proof.
- Automated tests added or updated, including the regression risk each protects.
- Delivery evidence for local branch work, including branch name and commit status if commits are created.
- Any deviations from the PRD and whether approval was obtained.
- Remaining human review for HV1-HV4.
- Not-done items and recommended follow-up candidates.
