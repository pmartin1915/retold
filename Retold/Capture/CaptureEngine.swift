import Foundation

// The R6a/R6b seam: R6a defines these protocols and drives them with mocks; R6b implements them
// with Apple APIs in Retold/Capture/Device/. CI green never means "the device path works".

/// The microphone, the audio file and the live transcriber behind one seam: on device one
/// AVAudioEngine tap feeds both the file and the SpeechAnalyzer input, so they share a clock.
protocol CaptureEngine: AnyObject, Sendable {
    func microphonePermission() async -> MicrophonePermission              // never prompts
    /// Prompts once if .undetermined. Onboarding only; never called on the capture path.
    func requestMicrophonePermission() async -> MicrophonePermission
    /// Activate the session, create the file at audioURL (ProtectionPlan.whileRecording), start the
    /// engine, start the live transcriber on `route` (none for .audioOnly). Emits engineStarted or
    /// engineStartFailed.
    func start(captureID: UUID, audioURL: URL, route: TranscriptionRoute) async
    func pause(captureID: UUID) async
    func resume(captureID: UUID) async
    /// Stop the engine; finalise the transcriber, emitting its last finals and then
    /// transcriberEnded(completed:) — true only if the run finished without error; close the file;
    /// deactivate the session; then emit engineStopped(duration:) last.
    ///
    /// Contract: stop always emits engineStopped eventually, even if start never completed or
    /// already failed (duration 0 in that case), and it is idempotent for a given capture ID.
    func stop(captureID: UUID) async
    /// The SAME stream on every access; single consumer (the coordinator).
    var events: AsyncStream<CaptureEngineEvent> { get }
}

enum CaptureEngineEvent: Equatable, Sendable {
    case recorder(RecorderEvent)
    case volatile(captureID: UUID, text: String)    // UI only
}

/// Re-transcribes a closed audio file (PLAN section 1: save audio first; transcribe from the file
/// if the live pass died). Yields final segments in audio-file time, then finishes; throws on failure.
protocol FileTranscriber: Sendable {
    func transcribe(audioURL: URL, route: TranscriptionRoute) -> AsyncThrowingStream<TranscriptSegment, Error>
}

/// The written length of a closed audio file; nil if unreadable.
protocol AudioDurationProbe: Sendable { func duration(of audioURL: URL) -> TimeInterval? }

/// Sets a file's Data Protection class. Real: FileManager.setAttributes; mock: records calls, can throw.
protocol FileProtector: Sendable { func protect(_ url: URL, as type: FileProtectionType) throws }
