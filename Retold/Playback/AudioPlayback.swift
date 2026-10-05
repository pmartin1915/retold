import AVFoundation
import Foundation
import Observation

/// The one shared audio player (R7b section 2). A thin device adapter over AVAudioPlayer, so it
/// has no unit tests; the device sitting checks it. One instance lives in RootView.
@MainActor @Observable
final class AudioPlayback {
    private(set) var captureID: UUID?          // the loaded capture, nil when stopped
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    @ObservationIgnored private let files: CaptureFiles
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var updateTask: Task<Void, Never>?

    init(files: CaptureFiles) {
        self.files = files
    }

    /// The audio file exists. One FileManager call, cheap enough per row.
    func canPlay(_ captureID: UUID) -> Bool {
        FileManager.default.fileExists(atPath: files.audioURL(for: captureID).path)
    }

    /// Plays `captureID`, from `time` if given. The same capture, loaded and paused, resumes
    /// (seeking first if `time` is given); a different capture loaded is stopped first. Any
    /// failure (a missing file, a decode failure, a session error) stops quietly: no alert.
    func play(_ captureID: UUID, from time: TimeInterval? = nil) {
        if self.captureID == captureID, let player {
            if let time { seek(to: time) }
            guard player.play() else {
                stop()
                return
            }
            isPlaying = true
            currentTime = player.currentTime
            startUpdates()
            return
        }
        if self.captureID != nil {
            stop(deactivateSession: false)
        }
        do {
            // The URL is always files.audioURL(for:); nothing else builds an audio path.
            let newPlayer = try AVAudioPlayer(contentsOf: files.audioURL(for: captureID))
            self.player = newPlayer
            self.captureID = captureID
            duration = newPlayer.duration
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback)
            try session.setActive(true)
            if let time {
                newPlayer.currentTime = min(max(time, 0), newPlayer.duration)
            }
            guard newPlayer.play() else {
                stop()
                return
            }
            isPlaying = true
            currentTime = newPlayer.currentTime
            startUpdates()
        } catch {
            stop()
        }
    }

    /// Cancels the update task and keeps the capture loaded.
    func pause() {
        guard let player else { return }
        updateTask?.cancel()
        updateTask = nil
        player.pause()
        isPlaying = false
        currentTime = player.currentTime
    }

    /// Clamps to 0...duration.
    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clamped = min(max(time, 0), duration)
        player.currentTime = clamped
        currentTime = clamped
    }

    /// Strictly a no-op when nothing is loaded: it touches neither the session nor any property.
    /// Otherwise it stops the player, cancels the update task, resets every property and, if
    /// `deactivateSession`, deactivates the session (ignoring the error).
    func stop(deactivateSession: Bool = true) {
        guard captureID != nil else { return }
        player?.stop()
        player = nil
        updateTask?.cancel()
        updateTask = nil
        captureID = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        if deactivateSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    /// One task updates currentTime every 0.25 s while playing. Seeing the player stopped without a
    /// pause() call (pause cancels this task) means it reached the end.
    private func startUpdates() {
        updateTask?.cancel()
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled, let self, let player = self.player else { return }
                if player.isPlaying {
                    self.currentTime = player.currentTime
                } else {
                    self.stop()
                    return
                }
            }
        }
    }
}
