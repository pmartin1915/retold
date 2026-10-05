# R7c spec: deleting an unfiled capture

_Written 2026-10-04, after R7b merged (PR #12, `47d5edd`). Perry decided on 2026-10-04 that deleting an
unfiled capture ships in 1.0 (R7B-SPEC §11). The scope is the one §11 named: unfiled captures only,
swipe to delete, one confirmation. The contract is the same as R1–R7b: every type, file, rule and test
name is fixed here. Target (Perry): Retold submitted ~10-27._

## Scope

**In:**

- A swipe-to-delete action on every row of Home's Unfiled section, including rows still transcribing.
- One confirmation dialog. Confirming removes the `Capture` record, its audio file and any journal file
  left for it.
- `CaptureDeleter`, the only code path that deletes a capture.
- New copy in `AppCopy`.

**No schema change.**

**Out:**

- Deleting a filed capture, an episode, a period, a person or a place.
- A delete button inside `ConfirmView`. That goes to IDEAS (§9).
- Undo, and a "recently deleted" bin. The dialog says the delete is permanent.
- Removing the capture from exports already shared. An exported zip is out of the app's reach. A zip
  built before the delete stays in tmp until the next launch sweep (`ExportArchiver.sweep`).

## 1. Why the order matters

`JournalImporter` runs at launch and on every import. Each pass can bring a deleted capture back:

- **Pass 1** imports any `<id>.jsonl` journal that has no `Capture` row.
- **Pass 2** adopts any `<id>.m4a` audio file that has no journal and no `Capture` row
  (`JournalImporter.swift`, `importOrphanAudio`).

So if the record went first and a file removal then failed, the next import would resurrect the
recording as a new unfiled capture. **Files go first and the record goes last.** A failure part-way
leaves a record whose files are partly or wholly gone. The user can see that row and delete it again,
and no file outlives its record. Such a row may keep its old label: one that said "Transcribing…" goes
on saying it after its audio is gone, because the file pass skips a capture with no audio. This is
accepted, because the next delete removes it.

Missing files are not errors. A retry after a partial failure finds some files already gone and carries
on.

## 2. `CaptureDeleter` (new file `Retold/Capture/CaptureDeleter.swift`)

```swift
enum CaptureDeleteError: Error, Equatable {
    case filed               // capture.episode != nil at delete time
    case active              // the capture is the coordinator's active capture
    case fileRemovalFailed   // a file exists and could not be removed; nothing else was touched after it
    case saveFailed          // files are gone; the record delete was rolled back
}

@MainActor
enum CaptureDeleter {
    /// Deletes one unfiled capture: journal files, then audio, then the record.
    /// An absent capture is success (already deleted). `remove` is injectable for tests.
    static func delete(
        captureID: UUID,
        activeCaptureID: UUID?,
        files: CaptureFiles,
        in container: ModelContainer,
        remove: (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }
    ) throws
}
```

The deleter works in a FRESH `ModelContext(container)` with `autosaveEnabled = false`, never in the
main context. This is the same pattern as `applyFilePassResult` and `JournalImporter`. A rollback in
the main context would discard unrelated unsaved edits (`JournalImporter.swift` header). Home's `@Query`
picks up the save.

Rules, in order:

1. If `captureID == activeCaptureID`, throw `.active`.
2. Re-fetch the capture by id in that fresh context (`fetchLimit = 1`). If the fetch throws, throw `.saveFailed`
   and remove nothing, because a fetch error does not mean the capture is absent (the same rule as
   `JournalImporter.fetchCapture`). If it is absent, return. If `episode != nil`, throw `.filed`.
   The re-fetch matters: `AnswerAttacher` can attach the capture between the swipe and the confirm.
3. Remove these files, in this order. Before each one, check `FileManager.default.fileExists(atPath:)`.
   If the file is absent, skip it without calling `remove`. If `remove` throws, throw
   `.fileRemovalFailed` and stop:
   1. `files.journalURL(for:)`, the `.jsonl`;
   2. the same URL with `.bad` appended (a quarantined journal still holds transcript text);
   3. `files.audioURL(for:)`.
4. `context.delete(capture)`, then `try context.save()`. On a save error, call `context.rollback()`
   and throw `.saveFailed`.

There is no suspension point anywhere in `delete`. Every writer is on the main actor, so nothing
interleaves with it.

**The file pass needs no change.** `applyFilePassResult` re-fetches by id and returns if the capture
is gone (`CaptureCoordinator.swift`). If the transcriber is reading the audio when it is removed, the
transcription throws, `segments` is nil, and the re-fetch finds nothing. A test pins this (§6).

**Coordinator change:** the computed `CaptureCoordinator.activeCaptureID` drops `private`, becoming
an internal read-only property. Nothing else in the coordinator changes.

## 3. Home (edit `Retold/Screens/HomeView.swift`)

- New state: `@State private var pendingDeleteID: UUID?` and `@State private var deleteFailed = false`.
  It holds the **id**, never a `Capture`. Reading a property of a deleted SwiftData model can trap.
- Apply this once, at the call site `unfiledRow(capture)` inside the Unfiled `ForEach`, so it covers
  all three row states:

  ```swift
  .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      Button(AppCopy.deleteAction, role: .destructive) { pendingDeleteID = capture.id }
  }
  ```

  Set `allowsFullSwipe` to false, so that a full swipe never deletes without the dialog. The swipe
  action is the only entry. VoiceOver reaches it through the actions rotor, with no extra work.
- One dialog:

  ```swift
  .confirmationDialog(
      AppCopy.deleteRecordingTitle,
      isPresented: Binding(get: { pendingDeleteID != nil }, set: { if !$0 { pendingDeleteID = nil } }),
      titleVisibility: .visible,
      presenting: pendingDeleteID
  ) { id in
      Button(AppCopy.deleteRecordingConfirm, role: .destructive) { deleteCapture(id) }
  } message: { _ in
      Text(AppCopy.deleteRecordingMessage)
  }
  ```

  Cancel is the system's own button. The action receives the id as presented data, so it still has it
  after the binding clears.
- `deleteCapture(_ id: UUID)` runs on the main actor:
  1. Call `CaptureDeleter.delete(captureID: id, activeCaptureID: coordinator.activeCaptureID, files:
     coordinator.files, in: modelContext.container)`.
  2. On success, set `outcomes[id] = nil`.
  3. On `.filed`, do nothing: the row has already left Unfiled.
  4. On any other error, set `deleteFailed = true`.
- An `.alert(AppCopy.deleteFailed, isPresented: $deleteFailed)` with an OK button.

**No playback handling is needed.** Unfiled rows have no play button and `ConfirmView` never plays,
so the shared player can only hold a filed capture, and a filed capture cannot be deleted.

## 4. Questions and answers

An unfiled capture can carry `answersQuestionID`, because it answers a period question or a theme
question. That question is only marked `.answered` when the capture is filed (`ConfirmFiler`). An
answer to an episode's question is attached at once and never shows in Unfiled (`AnswerAttacher`). So
deleting an unfiled capture leaves its question exactly as it was: still open, and its `askedCount`
unchanged. Nothing in R7c writes to a `Question`.

No `Detail`, `Question` slot or `Episode` excerpt can reference an unfiled capture, because all of them
are written only when a capture is filed. There is nothing to cascade.

## 5. Copy (append to `AppCopy` and to `AppCopy.all`)

| Name | Text |
|---|---|
| `deleteAction` | `Delete` |
| `deleteRecordingTitle` | `Delete this recording?` |
| `deleteRecordingMessage` | `The recording and its transcript will be removed from this phone. This can't be undone.` |
| `deleteRecordingConfirm` | `Delete recording` |
| `deleteFailed` | `The recording couldn't be deleted. Try again.` |

`WellnessLintTests.testAppCopyIsNonEmptyAndClean` already covers these through `AppCopy.all`.

## 6. Tests (new file `RetoldTests/CaptureDeleterTests.swift`)

These use an in-memory container (`RetoldSchema.makeInMemoryContainer()`) and a temp `CaptureFiles`
root, as `JournalImporterTests` does. The **bold** tests are required: the PR does not merge without
them.

1. **`testDeleteRemovesRecordAudioAndJournals`**: an unfiled capture with an audio file, a `.jsonl`
   and a `.jsonl.bad`. After the delete, the record and all three files are gone.
2. **`testDeletedCaptureIsNotResurrectedByImport`**: delete, then run
   `JournalImporter(files:durationProbe:protector:).importAll(into: container, excluding: nil)`. Use
   `MockDurationProbe` and `MockFileProtector`, as `JournalImporterTests` does. The report's
   `adoptedOrphans`, `imported` and `alreadyPresent` are all empty, and no `Capture` with that id exists.
3. **`testAudioRemovalFailureKeepsRecord`**: `remove` throws for the audio URL only. The delete throws
   `.fileRemovalFailed`, the record still exists, and the audio file still exists.
4. `testJournalRemovalFailureTouchesNothingAfter`: `remove` throws for the `.jsonl`. The delete throws
   `.fileRemovalFailed`, and the audio and the record both still exist.
5. **`testRetryAfterPartialFailureSucceeds`**: run test 3's failure, then delete again with the real
   `remove`. It succeeds, and the record and all files are gone.
6. `testMissingFilesStillDeleteRecord`: a capture with no files on disk deletes cleanly.
7. **`testDeleteRefusesFiledCapture`**: a capture attached to an episode. The delete throws `.filed`,
   and the record and audio are untouched.
8. `testDeleteRefusesActiveCapture`: `activeCaptureID == captureID`. The delete throws `.active`, and
   nothing is touched.
9. `testDeleteOfAbsentCaptureIsSuccess`: a random id returns without throwing.
10. **`testFilePassResultAfterDeleteIsNoOp`**: delete, then call
    `CaptureCoordinator.applyFilePassResult(captureID:segments:in: container)` with segments. No capture exists
    afterwards.
11. `testDeleteLeavesAnsweredQuestionOpen`: a period question, and an unfiled capture whose
    `answersQuestionID` is that question. After the delete, the question's `status` and `askedCount`
    are unchanged.

There is no UI test. Device check (§8) covers the swipe and the dialog.

## 7. Files touched

- New: `Retold/Capture/CaptureDeleter.swift`, `RetoldTests/CaptureDeleterTests.swift`.
- Edited:
  - `Retold/Screens/HomeView.swift` (§3);
  - `Retold/Copy/AppCopy.swift` (§5);
  - `Retold/Capture/CaptureCoordinator.swift` (the `activeCaptureID` visibility, and nothing else).
- XcodeGen (`project.yml`) picks up the new files from the source folders, so no project edit is
  needed.

## 8. Done when

1. CI is green on the full suite, including all eleven tests in §6.
2. A Sonnet `reviewer` pass has been folded in.
3. The build is on TestFlight.
4. Device check, folded into Perry's device sitting:
   1. Record a short throwaway. Swipe its Unfiled row and confirm. The row disappears.
   2. Force-quit and relaunch. It does not come back.
   3. Swipe a second row and cancel. It stays.
   4. Play an episode, then delete an unfiled row while it plays. Playback carries on, and nothing
      crashes.

## 9. `ai/IDEAS.md` additions (append-only, in the R7c PR)

- 2026-10-04 (R7c): add a Delete button inside `ConfirmView`, so the user can delete a botched
  recording from the screen where they notice it. 1.0 has swipe-only on Home.
- 2026-10-04 (R7c): add deleting filed captures and episodes. These need cascade rules for Details,
  Questions and excerpts that quote the capture. 1.1 at the earliest.

## 10. Review record

Sonnet spec review (fresh context, 2026-10-04): APPROVE WITH CHANGES. It found no resurrection path.

**All nine findings are folded in:**

- The deleter uses a fresh context, not the main context (a rollback would hazard unrelated edits).
- The dialog holds an id state rather than a `Capture`, because reading a deleted model can trap.
- The dialog binding is written out explicitly.
- Each file removal is guarded by `fileExists`.
- The playback step is dropped (unfiled rows cannot play), and device check 8.4 is reworded to match.
- `.swipeActions` is applied once at the call site.
- The test 2 assertions and harness are named.
- A sentence on the tmp export zip is added.
- The stale "Transcribing…" partial state is accepted.
