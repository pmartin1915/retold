import Foundation
import XCTest
@testable import Retold

/// The recorder reducer, exhaustively (docs/R6-RECORDER-SPEC.md §2.2).
final class RecorderMachineTests: XCTestCase {
    private let id = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
    private let otherID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeState(permission: MicrophonePermission = .granted,
                           protectedDataAvailable: Bool = true,
                           route: TranscriptionRoute = .audioOnly(.notChecked)) -> RecorderState {
        RecorderState(permission: permission, protectedDataAvailable: protectedDataAvailable, route: route)
    }

    /// startRequested while granted -> .starting(newID), startEngine with the current route.
    private func startRecording(_ state: RecorderState,
                                answering: UUID? = nil) -> (RecorderState, [RecorderEffect]) {
        RecorderMachine.reduce(state, .startRequested(answering: answering), now: now) { self.id }
    }

    // MARK: - Start

    func testStartWithoutPermissionBlocks() {
        for permission in [MicrophonePermission.undetermined, .denied] {
            let (state, effects) = RecorderMachine.reduce(
                makeState(permission: permission), .startRequested(answering: nil), now: now) { self.id }
            XCTAssertEqual(state.phase, .blocked)
            XCTAssertEqual(state.permission, permission)
            XCTAssertTrue(effects.isEmpty)
        }
    }

    func testPermissionChangeWhileBlocked() {
        var state = makeState(permission: .undetermined)
        (state, _) = RecorderMachine.reduce(state, .startRequested(answering: nil), now: now) { self.id }
        XCTAssertEqual(state.phase, .blocked)

        // .denied updates permission; the dropped request is not replayed.
        (state, _) = RecorderMachine.reduce(state, .permissionChanged(.denied), now: now) { self.id }
        XCTAssertEqual(state.phase, .blocked)
        XCTAssertEqual(state.permission, .denied)

        // .granted clears the block back to .idle, still with no start.
        let (grantedState, effects) = RecorderMachine.reduce(
            state, .permissionChanged(.granted), now: now) { self.id }
        XCTAssertEqual(grantedState.phase, .idle)
        XCTAssertEqual(grantedState.permission, .granted)
        XCTAssertTrue(effects.isEmpty)
    }

    func testStartEmitsStartEngineWithRoute() {
        var state = makeState(route: .audioOnly(.notChecked))
        (state, _) = RecorderMachine.reduce(
            state, .routeChanged(.speech(localeID: "en_US")), now: now) { self.id }
        let (started, effects) = startRecording(state, answering: nil)
        XCTAssertEqual(started.phase, .starting(captureID: id, stopRequested: false))
        XCTAssertEqual(effects, [.startEngine(captureID: id, route: .speech(localeID: "en_US"))])
    }

    func testRouteChangeIgnoredWhileRecording() {
        var (state, _) = startRecording(makeState())
        (state, _) = RecorderMachine.reduce(state, .engineStarted(captureID: id), now: now) { self.id }
        let (unchanged, effects) = RecorderMachine.reduce(
            state, .routeChanged(.dictation(localeID: "en_US")), now: now) { self.id }
        XCTAssertEqual(unchanged.phase, .recording(captureID: id))
        XCTAssertEqual(unchanged.route, .audioOnly(.notChecked))
        XCTAssertTrue(effects.isEmpty)
    }

    // MARK: - Engine start

    func testEngineStartedOpensJournalThenBegins() {
        let answering = UUID(uuidString: "00000000-0000-0000-0000-0000000000C3")!
        let (state, _) = startRecording(makeState(route: .speech(localeID: "en_US")), answering: answering)
        let (recording, effects) = RecorderMachine.reduce(state, .engineStarted(captureID: id), now: now) { self.id }
        XCTAssertEqual(recording.phase, .recording(captureID: id))
        let expectedBegin = JournalRecord.begin(
            id, audioFileName: CaptureFiles.audioFileName(for: id), createdAt: now,
            answering: answering, route: .speech(localeID: "en_US"))
        XCTAssertEqual(effects, [.openJournal(captureID: id), .journal(expectedBegin)])
    }

    func testEngineStartFailedReturnsToIdleWithoutJournal() {
        let (state, _) = startRecording(makeState(), answering: UUID())
        let (idle, effects) = RecorderMachine.reduce(state, .engineStartFailed(captureID: id), now: now) { self.id }
        XCTAssertEqual(idle.phase, .idle)
        XCTAssertNil(idle.answering)
        XCTAssertTrue(effects.isEmpty)
    }

    func testStopDuringStartingStopsRightAfterStart() {
        let (state, _) = startRecording(makeState())
        let (stoppingRequested, tapEffects) = RecorderMachine.reduce(state, .tapStop, now: now) { self.id }
        XCTAssertEqual(stoppingRequested.phase, .starting(captureID: id, stopRequested: true))
        XCTAssertTrue(tapEffects.isEmpty)

        let (stopping, effects) = RecorderMachine.reduce(
            stoppingRequested, .engineStarted(captureID: id), now: now) { self.id }
        XCTAssertEqual(stopping.phase, .stopping(captureID: id, reason: .userStop))
        let expectedBegin = JournalRecord.begin(
            id, audioFileName: CaptureFiles.audioFileName(for: id), createdAt: now,
            answering: nil, route: .audioOnly(.notChecked))
        XCTAssertEqual(effects, [
            .openJournal(captureID: id),
            .journal(expectedBegin),
            .stopEngine(captureID: id),
        ])
    }

    func testFailureDuringStartingAbortsAndStopsEngine() {
        for event in [RecorderEvent.mediaServicesReset, .engineFailed] {
            let (state, _) = startRecording(makeState())
            let (aborting, effects) = RecorderMachine.reduce(state, event, now: now) { self.id }
            XCTAssertEqual(aborting.phase, .aborting(captureID: id), "\(event)")
            XCTAssertEqual(effects, [.stopEngine(captureID: id)], "\(event)")

            // A late engineStarted during .aborting stops the engine again.
            let (stillAborting, lateEffects) = RecorderMachine.reduce(
                aborting, .engineStarted(captureID: id), now: now) { self.id }
            XCTAssertEqual(stillAborting.phase, .aborting(captureID: id), "\(event)")
            XCTAssertEqual(lateEffects, [.stopEngine(captureID: id)], "\(event)")

            // engineStopped then returns to .idle with no journal effects.
            let (idle, endEffects) = RecorderMachine.reduce(
                stillAborting, .engineStopped(captureID: id, duration: 0), now: now) { self.id }
            XCTAssertEqual(idle.phase, .idle, "\(event)")
            XCTAssertNil(idle.answering)
            XCTAssertEqual(idle.runOffsets, [:], "\(event)")
            XCTAssertTrue(endEffects.isEmpty, "\(event)")
        }
    }

    // §7a: a second Action press stops the recording; it never starts a second capture.

    func testSecondStartStopsRecording() {
        var (state, _) = startRecording(makeState())
        (state, _) = RecorderMachine.reduce(state, .engineStarted(captureID: id), now: now) { self.id }
        let (stopping, effects) = RecorderMachine.reduce(
            state, .startRequested(answering: nil), now: now) { self.otherID }
        XCTAssertEqual(stopping.phase, .stopping(captureID: id, reason: .userStop))
        XCTAssertEqual(effects, [.stopEngine(captureID: id)])
    }

    func testSecondStartWhileInterruptedStops() {
        var (state, _) = startRecording(makeState())
        (state, _) = RecorderMachine.reduce(state, .engineStarted(captureID: id), now: now) { self.id }
        (state, _) = RecorderMachine.reduce(state, .interruptionBegan, now: now) { self.id }
        let (stopping, effects) = RecorderMachine.reduce(
            state, .startRequested(answering: nil), now: now) { self.otherID }
        XCTAssertEqual(stopping.phase, .stopping(captureID: id, reason: .userStop))
        XCTAssertEqual(effects, [.stopEngine(captureID: id)])
    }

    func testSecondStartWhileStartingRequestsStop() {
        let (state, _) = startRecording(makeState())
        let (starting, effects) = RecorderMachine.reduce(
            state, .startRequested(answering: nil), now: now) { self.otherID }
        XCTAssertEqual(starting.phase, .starting(captureID: id, stopRequested: true))
        XCTAssertTrue(effects.isEmpty)
    }

    func testSecondStartWhileStoppingIsIgnored() {
        var (state, _) = startRecording(makeState())
        (state, _) = RecorderMachine.reduce(state, .engineStarted(captureID: id), now: now) { self.id }
        (state, _) = RecorderMachine.reduce(state, .tapStop, now: now) { self.id }
        let (unchanged, effects) = RecorderMachine.reduce(
            state, .startRequested(answering: nil), now: now) { self.otherID }
        XCTAssertEqual(unchanged, state)
        XCTAssertTrue(effects.isEmpty)
    }

    func testSecondStartWhileAbortingIsIgnored() {
        var (state, _) = startRecording(makeState())
        (state, _) = RecorderMachine.reduce(state, .engineFailed, now: now) { self.id }
        XCTAssertEqual(state.phase, .aborting(captureID: id))
        let (unchanged, effects) = RecorderMachine.reduce(
            state, .startRequested(answering: nil), now: now) { self.otherID }
        XCTAssertEqual(unchanged, state)
        XCTAssertTrue(effects.isEmpty)
    }

    // MARK: - Time limit (§7a)

    func testTimeLimitStopsRecording() {
        var (state, _) = startRecording(makeState())
        (state, _) = RecorderMachine.reduce(state, .engineStarted(captureID: id), now: now) { self.id }
        let (stopping, effects) = RecorderMachine.reduce(state, .timeLimitReached, now: now) { self.id }
        XCTAssertEqual(stopping.phase, .stopping(captureID: id, reason: .timeLimit))
        XCTAssertEqual(effects, [.stopEngine(captureID: id)])

        let (idle, endEffects) = RecorderMachine.reduce(
            stopping, .engineStopped(captureID: id, duration: 1800), now: now) { self.id }
        XCTAssertEqual(idle.phase, .idle)
        XCTAssertEqual(endEffects, [
            .journal(.end(id, duration: 1800, reason: .timeLimit, endedAt: now)),
            .closeJournal(captureID: id),
            .importJournals,
        ])
    }

    func testTimeLimitWhileInterruptedStops() {
        var (state, _) = startRecording(makeState())
        (state, _) = RecorderMachine.reduce(state, .engineStarted(captureID: id), now: now) { self.id }
        (state, _) = RecorderMachine.reduce(state, .interruptionBegan, now: now) { self.id }
        let (stopping, effects) = RecorderMachine.reduce(state, .timeLimitReached, now: now) { self.id }
        XCTAssertEqual(stopping.phase, .stopping(captureID: id, reason: .timeLimit))
        XCTAssertEqual(effects, [.stopEngine(captureID: id)])
    }

    func testTimeLimitIgnoredOutsideRecording() {
        let idle = makeState()
        let (starting, _) = startRecording(idle)
        var stopping = starting
        (stopping, _) = RecorderMachine.reduce(stopping, .engineStarted(captureID: id), now: now) { self.id }
        (stopping, _) = RecorderMachine.reduce(stopping, .tapStop, now: now) { self.id }
        for state in [idle, starting, stopping] {
            let (unchanged, effects) = RecorderMachine.reduce(state, .timeLimitReached, now: now) { self.id }
            XCTAssertEqual(unchanged, state)
            XCTAssertTrue(effects.isEmpty)
        }
    }

    // MARK: - Lock, scene and interruption

    func testBackgroundAndLockDoNotPauseRecording() {
        var (state, _) = startRecording(makeState())
        (state, _) = RecorderMachine.reduce(state, .engineStarted(captureID: id), now: now) { self.id }
        for event in [RecorderEvent.sceneDidEnterBackground, .sceneWillResignActive,
                      .protectedDataWillBecomeUnavailable] {
            let (unchanged, effects) = RecorderMachine.reduce(state, event, now: now) { self.id }
            XCTAssertEqual(unchanged.phase, .recording(captureID: id), "\(event)")
            XCTAssertTrue(effects.isEmpty, "\(event)")
        }
        // Only the protected-data event flips the flag; the phase never moved.
        let (locked, _) = RecorderMachine.reduce(
            state, .protectedDataWillBecomeUnavailable, now: now) { self.id }
        XCTAssertFalse(locked.protectedDataAvailable)
        XCTAssertEqual(locked.phase, .recording(captureID: id))
    }

    func testInterruptionPausesAndKeepsCapture() {
        var (state, _) = startRecording(makeState())
        (state, _) = RecorderMachine.reduce(state, .engineStarted(captureID: id), now: now) { self.id }
        let (interrupted, effects) = RecorderMachine.reduce(state, .interruptionBegan, now: now) { self.id }
        XCTAssertEqual(interrupted.phase, .interrupted(captureID: id))
        XCTAssertEqual(effects, [
            .pauseEngine(captureID: id),
            .journal(.paused(id, at: now)),
        ])
    }

    func testInterruptionEndedDoesNotAutoResume() {
        var (state, _) = startRecording(makeState())
        (state, _) = RecorderMachine.reduce(state, .engineStarted(captureID: id), now: now) { self.id }
        (state, _) = RecorderMachine.reduce(state, .interruptionBegan, now: now) { self.id }
        let (unchanged, effects) = RecorderMachine.reduce(
            state, .interruptionEnded(shouldResume: true), now: now) { self.id }
        XCTAssertEqual(unchanged.phase, .interrupted(captureID: id))
        XCTAssertTrue(effects.isEmpty)
    }

    func testTapResumeResumesSameCapture() {
        var (state, _) = startRecording(makeState())
        (state, _) = RecorderMachine.reduce(state, .engineStarted(captureID: id), now: now) { self.id }
        (state, _) = RecorderMachine.reduce(state, .interruptionBegan, now: now) { self.id }
        let (recording, effects) = RecorderMachine.reduce(state, .tapResume, now: now) { self.id }
        XCTAssertEqual(recording.phase, .recording(captureID: id))
        XCTAssertEqual(effects, [
            .resumeEngine(captureID: id),
            .journal(.resumed(id, at: now)),
        ])
    }

    // MARK: - Ending

    private func makeRecording() -> RecorderState {
        var (state, _) = startRecording(makeState())
        (state, _) = RecorderMachine.reduce(state, .engineStarted(captureID: id), now: now) { self.id }
        return state
    }

    func testStopThenEngineStoppedJournalsEndAndImportsWhenUnlocked() {
        var state = makeRecording()
        (state, _) = RecorderMachine.reduce(state, .tapStop, now: now) { self.id }
        let (idle, effects) = RecorderMachine.reduce(
            state, .engineStopped(captureID: id, duration: 30), now: now) { self.id }
        XCTAssertEqual(idle.phase, .idle)
        XCTAssertEqual(effects, [
            .journal(.end(id, duration: 30, reason: .userStop, endedAt: now)),
            .closeJournal(captureID: id),
            .importJournals,
        ])
    }

    func testStopWhileLockedDoesNotImport() {
        var state = makeRecording()
        (state, _) = RecorderMachine.reduce(state, .protectedDataWillBecomeUnavailable, now: now) { self.id }
        (state, _) = RecorderMachine.reduce(state, .tapStop, now: now) { self.id }
        let (idle, effects) = RecorderMachine.reduce(
            state, .engineStopped(captureID: id, duration: 30), now: now) { self.id }
        XCTAssertEqual(idle.phase, .idle)
        XCTAssertEqual(effects, [
            .journal(.end(id, duration: 30, reason: .userStop, endedAt: now)),
            .closeJournal(captureID: id),
        ])
    }

    func testFinalsAfterStopAreStillJournaled() {
        var state = makeRecording()
        (state, _) = RecorderMachine.reduce(state, .tapStop, now: now) { self.id }
        XCTAssertEqual(state.phase, .stopping(captureID: id, reason: .userStop))
        let segment = TranscriptSegment(text: "last words", start: 8, end: 9, isFinal: true)
        let (unchanged, effects) = RecorderMachine.reduce(
            state, .finalSegment(captureID: id, run: 0, segment: segment), now: now) { self.id }
        XCTAssertEqual(unchanged.phase, .stopping(captureID: id, reason: .userStop))
        XCTAssertEqual(effects, [.journal(.segment(id, run: 0, segment: segment))])
    }

    func testRunOffsetShiftsSegmentTimes() {
        var state = makeRecording()
        var (s, effects) = RecorderMachine.reduce(
            state, .transcriberRunStarted(captureID: id, run: 0, audioOffset: 0), now: now) { self.id }
        XCTAssertEqual(effects, [.journal(.runStarted(id, run: 0, audioOffset: 0))])

        let first = TranscriptSegment(text: "hello", start: 1, end: 2, isFinal: true)
        (s, effects) = RecorderMachine.reduce(s, .finalSegment(captureID: id, run: 0, segment: first),
                                              now: now) { self.id }
        XCTAssertEqual(effects, [.journal(.segment(id, run: 0, segment: first))])

        (s, effects) = RecorderMachine.reduce(
            s, .transcriberRunStarted(captureID: id, run: 1, audioOffset: 12.5), now: now) { self.id }
        XCTAssertEqual(s.runOffsets, [0: 0, 1: 12.5])
        XCTAssertEqual(effects, [.journal(.runStarted(id, run: 1, audioOffset: 12.5))])

        let second = TranscriptSegment(text: "world", start: 0, end: 1, isFinal: true)
        let (finalState, finalEffects) = RecorderMachine.reduce(
            s, .finalSegment(captureID: id, run: 1, segment: second), now: now) { self.id }
        let shifted = TranscriptSegment(text: "world", start: 12.5, end: 13.5, isFinal: true)
        XCTAssertEqual(finalEffects, [.journal(.segment(id, run: 1, segment: shifted))])
        // The text is byte-identical through the shift.
        if case .journal(let record) = finalEffects[0] {
            XCTAssertEqual(record.text, "world")
        } else {
            XCTFail("expected a journal effect")
        }
        state = finalState
        XCTAssertEqual(state.runOffsets, [0: 0, 1: 12.5])
    }

    func testLateFinalFromEarlierRunUsesItsOwnOffset() {
        var (state, _) = startRecording(makeState())
        (state, _) = RecorderMachine.reduce(state, .engineStarted(captureID: id), now: now) { self.id }
        (state, _) = RecorderMachine.reduce(
            state, .transcriberRunStarted(captureID: id, run: 0, audioOffset: 0), now: now) { self.id }
        (state, _) = RecorderMachine.reduce(
            state, .transcriberRunStarted(captureID: id, run: 1, audioOffset: 12.5), now: now) { self.id }
        // A late run-0 final still gets run 0's offset (zero), not run 1's.
        let late = TranscriptSegment(text: "late", start: 3, end: 4, isFinal: true)
        let (_, effects) = RecorderMachine.reduce(
            state, .finalSegment(captureID: id, run: 0, segment: late), now: now) { self.id }
        XCTAssertEqual(effects, [.journal(.segment(id, run: 0, segment: late))])
    }

    func testStaleCaptureIDIsIgnored() {
        var state = makeRecording()
        let staleStarted = RecorderMachine.reduce(state, .engineStarted(captureID: otherID), now: now) { self.id }
        XCTAssertEqual(staleStarted.0, state)
        XCTAssertTrue(staleStarted.1.isEmpty)

        let segment = TranscriptSegment(text: "x", start: 0, end: 1, isFinal: true)
        let staleFinal = RecorderMachine.reduce(
            state, .finalSegment(captureID: otherID, run: 0, segment: segment), now: now) { self.id }
        XCTAssertEqual(staleFinal.0, state)
        XCTAssertTrue(staleFinal.1.isEmpty)

        (state, _) = RecorderMachine.reduce(state, .tapStop, now: now) { self.id }
        let staleStopped = RecorderMachine.reduce(
            state, .engineStopped(captureID: otherID, duration: 5), now: now) { self.id }
        XCTAssertEqual(staleStopped.0, state)
        XCTAssertTrue(staleStopped.1.isEmpty)
    }

    func testMediaServicesResetEndsCapture() {
        var state = makeRecording()
        let (stopping, effects) = RecorderMachine.reduce(state, .mediaServicesReset, now: now) { self.id }
        XCTAssertEqual(stopping.phase, .stopping(captureID: id, reason: .mediaServicesReset))
        XCTAssertEqual(effects, [.stopEngine(captureID: id)])
        state = stopping

        (state, _) = RecorderMachine.reduce(
            state, .finalSegment(captureID: id, run: 0,
                                 segment: TranscriptSegment(text: "t", start: 0, end: 1, isFinal: true)),
            now: now) { self.id }
        (state, _) = RecorderMachine.reduce(state, .transcriberEnded(captureID: id, run: 0, completed: false),
                                            now: now) { self.id }
        let (idle, endEffects) = RecorderMachine.reduce(
            state, .engineStopped(captureID: id, duration: 7), now: now) { self.id }
        XCTAssertEqual(idle.phase, .idle)
        XCTAssertEqual(endEffects, [
            .journal(.end(id, duration: 7, reason: .mediaServicesReset, endedAt: now)),
            .closeJournal(captureID: id),
            .importJournals,
        ])
    }

    func testEngineFailedEndsCapture() {
        var state = makeRecording()
        (state, _) = RecorderMachine.reduce(state, .interruptionBegan, now: now) { self.id }
        let (stopping, effects) = RecorderMachine.reduce(state, .engineFailed, now: now) { self.id }
        XCTAssertEqual(stopping.phase, .stopping(captureID: id, reason: .engineFailed))
        XCTAssertEqual(effects, [.stopEngine(captureID: id)])
    }

    func testUnrequestedEngineStoppedEndsAsEngineFailed() {
        let state = makeRecording()
        let (idle, effects) = RecorderMachine.reduce(
            state, .engineStopped(captureID: id, duration: 3), now: now) { self.id }
        XCTAssertEqual(idle.phase, .idle)
        XCTAssertEqual(effects, [
            .journal(.end(id, duration: 3, reason: .engineFailed, endedAt: now)),
            .closeJournal(captureID: id),
            .importJournals,
        ])
    }

    func testUnlockEmitsImport() {
        var state = makeState(protectedDataAvailable: false)
        (state, _) = RecorderMachine.reduce(
            state, .protectedDataWillBecomeUnavailable, now: now) { self.id }
        let (unlocked, effects) = RecorderMachine.reduce(
            state, .protectedDataDidBecomeAvailable, now: now) { self.id }
        XCTAssertTrue(unlocked.protectedDataAvailable)
        XCTAssertEqual(effects, [.importJournals])
    }
}
