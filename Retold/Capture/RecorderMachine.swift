import Foundation

// The recorder reducer: state + event -> state + effects, with the reducer generating the IDs.
// Pure Foundation. Deliberate divergences from StoryCue's SessionMachine: locking is not a pause
// (UIBackgroundModes: audio keeps an active .record session alive), one capture is one audio file,
// and resume is always a user action.

enum MicrophonePermission: Equatable, Sendable { case undetermined, granted, denied }

enum CaptureEndReason: String, Codable, Equatable, Sendable {
    case userStop, mediaServicesReset, engineFailed
}

enum RecorderPhase: Equatable, Sendable {
    case idle
    case blocked                                  // a start was requested without .granted; see state.permission
    case starting(captureID: UUID, stopRequested: Bool)
    case recording(captureID: UUID)
    case interrupted(captureID: UUID)             // file open, engine paused, waiting for tapResume
    case stopping(captureID: UUID, reason: CaptureEndReason)
    case aborting(captureID: UUID)                // failed during .starting; waiting for engineStopped
}

struct RecorderState: Equatable, Sendable {
    var phase: RecorderPhase
    var permission: MicrophonePermission
    var protectedDataAvailable: Bool
    var route: TranscriptionRoute
    var answering: UUID?                          // the question the active capture answers
    var runOffsets: [Int: TimeInterval]           // transcriber run number -> audio-file time it began at

    init(permission: MicrophonePermission, protectedDataAvailable: Bool,
         route: TranscriptionRoute = .audioOnly(.notChecked)) {
        self.phase = .idle
        self.permission = permission
        self.protectedDataAvailable = protectedDataAvailable
        self.route = route
        self.answering = nil
        self.runOffsets = [:]
    }
}

enum RecorderEvent: Equatable, Sendable {
    case startRequested(answering: UUID?)         // Control intent or in-app Record button
    case permissionChanged(MicrophonePermission)
    case routeChanged(TranscriptionRoute)         // only honoured in .idle / .blocked
    case engineStarted(captureID: UUID)
    case engineStartFailed(captureID: UUID)
    case transcriberRunStarted(captureID: UUID, run: Int, audioOffset: TimeInterval)
    case finalSegment(captureID: UUID, run: Int, segment: TranscriptSegment)   // run-relative times
    case transcriberEnded(captureID: UUID, run: Int, completed: Bool)
    case interruptionBegan, interruptionEnded(shouldResume: Bool)
    case tapResume, tapStop
    case engineStopped(captureID: UUID, duration: TimeInterval)
    case mediaServicesReset, engineFailed
    case protectedDataWillBecomeUnavailable, protectedDataDidBecomeAvailable
    case sceneDidEnterBackground, sceneWillResignActive, sceneDidBecomeActive
}

enum RecorderEffect: Equatable, Sendable {
    case startEngine(captureID: UUID, route: TranscriptionRoute)
    case pauseEngine(captureID: UUID)
    case resumeEngine(captureID: UUID)
    case stopEngine(captureID: UUID)
    case openJournal(captureID: UUID)
    case journal(JournalRecord)
    case closeJournal(captureID: UUID)
    case importJournals                            // only ever emitted while protectedDataAvailable
}

enum RecorderMachine {
    /// `newID` is the reducer's only source of capture IDs (injected so tests are deterministic).
    static func reduce(_ state: RecorderState, _ event: RecorderEvent, now: Date,
                       newID: () -> UUID) -> (RecorderState, [RecorderEffect]) {
        var s = state
        switch event {
        case .startRequested(let answering):
            switch s.phase {
            case .idle, .blocked:
                // Without .granted the request is dropped; a later grant does not replay it.
                guard s.permission == .granted else {
                    s.phase = .blocked
                    return (s, [])
                }
                let n = newID()
                s.phase = .starting(captureID: n, stopRequested: false)
                s.answering = answering
                s.runOffsets = [:]
                return (s, [.startEngine(captureID: n, route: s.route)])
            default:
                // A second Action press never starts a second capture.
                return (state, [])
            }

        case .permissionChanged(let p):
            s.permission = p
            if case .blocked = s.phase, p == .granted {
                s.phase = .idle
            }
            return (s, [])

        case .routeChanged(let r):
            switch s.phase {
            case .idle, .blocked:
                s.route = r
                return (s, [])
            default:
                return (state, [])
            }

        case .engineStarted(let id):
            switch s.phase {
            case .starting(let pid, let stopRequested) where pid == id:
                let begin = RecorderEffect.journal(.begin(
                    id,
                    audioFileName: CaptureFiles.audioFileName(for: id),
                    createdAt: now,
                    answering: s.answering,
                    route: s.route
                ))
                if stopRequested {
                    s.phase = .stopping(captureID: id, reason: .userStop)
                    return (s, [.openJournal(captureID: id), begin, .stopEngine(captureID: id)])
                }
                s.phase = .recording(captureID: id)
                return (s, [.openJournal(captureID: id), begin])
            case .aborting(let pid) where pid == id:
                return (state, [.stopEngine(captureID: id)])
            default:
                return (state, [])
            }

        case .engineStartFailed(let id):
            if case .starting(let pid, _) = s.phase, pid == id {
                s.phase = .idle
                s.answering = nil
                return (s, [])          // nothing was journaled
            }
            return (state, [])

        case .tapStop:
            switch s.phase {
            case .starting(let id, _):
                s.phase = .starting(captureID: id, stopRequested: true)
                return (s, [])
            case .recording(let id), .interrupted(let id):
                s.phase = .stopping(captureID: id, reason: .userStop)
                return (s, [.stopEngine(captureID: id)])
            default:
                return (state, [])
            }

        case .mediaServicesReset, .engineFailed:
            let reason: CaptureEndReason = event == .mediaServicesReset ? .mediaServicesReset : .engineFailed
            switch s.phase {
            case .starting(let id, _):
                s.phase = .aborting(captureID: id)
                return (s, [.stopEngine(captureID: id)])
            case .recording(let id), .interrupted(let id):
                s.phase = .stopping(captureID: id, reason: reason)
                return (s, [.stopEngine(captureID: id)])
            default:
                return (state, [])
            }

        case .transcriberRunStarted(let id, let run, let audioOffset):
            switch s.phase {
            case .recording(let pid) where pid == id,
                 .interrupted(let pid) where pid == id,
                 .stopping(let pid, _) where pid == id:
                s.runOffsets[run] = audioOffset
                return (s, [.journal(.runStarted(id, run: run, audioOffset: audioOffset))])
            default:
                return (state, [])
            }

        case .finalSegment(let id, let run, let segment):
            switch s.phase {
            case .recording(let pid) where pid == id,
                 .interrupted(let pid) where pid == id,
                 .stopping(let pid, _) where pid == id:
                // §2.3: shift run-relative times to audio-file time by run.
                let shifted = TranscriptSegment(
                    text: segment.text,
                    start: segment.start + (s.runOffsets[run] ?? 0),
                    end: segment.end + (s.runOffsets[run] ?? 0),
                    isFinal: true
                )
                return (s, [.journal(.segment(id, run: run, segment: shifted))])
            default:
                return (state, [])
            }

        case .transcriberEnded(let id, let run, let completed):
            switch s.phase {
            case .recording(let pid) where pid == id,
                 .interrupted(let pid) where pid == id,
                 .stopping(let pid, _) where pid == id:
                return (s, [.journal(.transcriberEnded(id, run: run, completed: completed))])
            default:
                return (state, [])
            }

        case .interruptionBegan:
            if case .recording(let id) = s.phase {
                s.phase = .interrupted(captureID: id)
                return (s, [.pauseEngine(captureID: id), .journal(.paused(id, at: now))])
            }
            return (state, [])

        case .interruptionEnded:
            // Divergence 3: never auto-resume.
            return (state, [])

        case .tapResume:
            if case .interrupted(let id) = s.phase {
                s.phase = .recording(captureID: id)
                return (s, [.resumeEngine(captureID: id), .journal(.resumed(id, at: now))])
            }
            return (state, [])

        case .engineStopped(let id, let duration):
            switch s.phase {
            case .stopping(let pid, let reason) where pid == id:
                return finishCapture(&s, id: id, duration: duration, reason: reason, now: now)
            case .recording(let pid) where pid == id, .interrupted(let pid) where pid == id:
                // An unrequested stop ends the capture as .engineFailed.
                return finishCapture(&s, id: id, duration: duration, reason: .engineFailed, now: now)
            case .aborting(let pid) where pid == id:
                s.phase = .idle
                s.answering = nil
                s.runOffsets = [:]
                return (s, [])
            default:
                return (state, [])
            }

        case .protectedDataWillBecomeUnavailable:
            s.protectedDataAvailable = false
            return (s, [])

        case .protectedDataDidBecomeAvailable:
            s.protectedDataAvailable = true
            return (s, [.importJournals])

        case .sceneDidEnterBackground, .sceneWillResignActive, .sceneDidBecomeActive:
            // Divergence 1: scene events never change the phase.
            return (state, [])
        }
    }

    /// engineStopped is the last event of a capture: journal the end, close the journal,
    /// then import — but only while protected data is available.
    private static func finishCapture(_ s: inout RecorderState, id: UUID, duration: TimeInterval,
                                      reason: CaptureEndReason, now: Date) -> (RecorderState, [RecorderEffect]) {
        s.phase = .idle
        s.answering = nil
        s.runOffsets = [:]
        var effects: [RecorderEffect] = [
            .journal(.end(id, duration: duration, reason: reason, endedAt: now)),
            .closeJournal(captureID: id),
        ]
        if s.protectedDataAvailable {
            effects.append(.importJournals)
        }
        return (s, effects)
    }
}
