# Retold QA review (Kimi, independent reviewer 3 of 3)

Scored from
the packet only. HOUSE-STYLE rules 1-26 and APPLE-IPHONE-DUO-PREP are reference
d by the rubric but their text is not in the packet, so dimension 5 cannot be c
hecked against the numbered rules and dimension 8 cannot be checked against the
foldable-hazard list; where relevant I say so rather than invent citations.


## Score table

| # | Dimension | Score | Note |
|---|-----------|-------|--
----|
| 1 | Motion and fluidity | 2 | No haptics anywhere, hard recorder<->hom
e cut, blank flash in ConfirmView; taps mostly respond |
| 2 | State clarity |
3 | Export/stopping/empty states good; one silent failure, no single-flight on 
work-starting taps |
| 3 | Input/recording robustness | 3 | State machine thor
ough (interruptions, resets, protected data); rapid double-tap can cancel a wan
ted capture |
| 4 | Accessibility | 2 | One explicit label in the app; icon-on
ly buttons unlabeled, no Reduce Motion/Bold Text handling visible |
| 5 | Visu
al system | 2 | HOUSE-STYLE not in packet; hard-coded .red/.yellow one-offs vs 
veterans' token systems |
| 6 | Performance | 2 | Per-row/per-body sorting; e
xport manifest built on main actor |
| 7 | Copy | 3 | Centralized AppCopy, pla
in empty states; raw error string concatenated into one alert |
| 8 | Layout r
esilience | 3 | No UIScreen.main or portrait lock visible in excerpts (good sig
ns); prep doc not in packet |

No blockers found. 11 findings, ordered should
-> polish.

## Findings

FINDING 1
- dimension: 2
- severity: should
- t
arget: retold/Retold/Screens/PeriodsView.swift:116  quote: "// .emptyTitle and 
save failures keep the sheet open, with no alert."
- veteran counterpart: reto
ld/Retold/Screens/OfferRow.swift:44  quote: ".alert(AppCopy.saveFailedTitle, is
Presented: $saveFailed) {"
- evidence: save()'s catch-all is an empty block, 
so a SwiftData save failure leaves the sheet open with zero feedback; the user 
taps Save repeatedly and nothing happens. The target's own OfferRow, SetAsideV
iew (lines 36-40) and HomeView delete/start failures all surface an alert - Per
iodEditSheet is the one silent path.
- fix: Add a saveFailed @State and an .al
ert(AppCopy.saveFailedTitle, message: saveFailedMessage), mirroring OfferRow. F
or .emptyTitle, show the same duplicate-style footnote so the user knows why th
e sheet stayed open.

FINDING 2
- dimension: 7
- severity: should
- target
: retold/Retold/Screens/HomeView.swift:138  quote: "Text(AppCopy.startFailedMes
sage + (coordinator.startFailure ?? \"\"))"
- veteran counterpart: BoardBoun
d/boardbound/app/quiz/question.tsx:176  quote: "\"Questions may not have loade
d yet. Try restarting the app.\""
- evidence: The alert concatenates a raw in
ternal error value (OSStatus, engine description, anything coordinator.startFai
lure holds) onto user copy, so users can see jargon or empty text when the fail
ure is nil-adjacent. The veteran empty/error copy says what happened and what t
o do, with no internals.
- fix: Map known failure cases to plain sentences in 
AppCopy (e.g. "Recording could not start. Check the microphone and try again.")
and keep the raw string in os_log, not in the alert.

FINDING 3
- dimension:
2
- severity: should
- target: retold/Retold/Screens/OfferRow.swift:22  quote
: "Button(AppCopy.answerNow) {"
- veteran counterpart: retold/Retold/Capture/R
ecorderMachine.swift:91  quote: "// SS7a: a second Action press stops the recor
ding as soon as it starts"
- evidence: answerNow() and HomeView's Record butt
on (HomeView.swift:41) are never disabled while work starts. A rapid second tap
sends a second startRequested while phase is .starting, and the machine (Record
erMachine.swift:92-94) sets stopRequested: true - so the recording the user wan
ted is cancelled the instant the engine starts, with no explanation. That behav
ior is correct for the Control/Action button but reachable from in-app buttons 
too.
- fix: Gate the in-app paths: disable the button (or guard on a transient
isStarting flag) from first tap until phase leaves .starting/idle, so the SS7a 
second-press semantics only come from the Control/Action intents.

FINDING 4n- dimension: 1
- severity: should
- target: retold/Retold/Screens/RecorderVi
ew.swift:71  quote: "Button(AppCopy.stopButton) {"
- veteran counterpart: wild
erness/src/services/nativeHaptics.ts:33  quote: "export async function haptic(s
tyle: HapticStyle = 'medium'): Promise<void> {"
- evidence: A grep of the ex
cerpts shows no haptic of any kind: no UIImpactFeedbackGenerator/UINotification
FeedbackGenerator equivalent, no call at record start/stop (RecorderView.swift:
71-73), Resume (line 51), PlayPauseButton (HomeView.swift:274-279), or File/Sav
e. Veterans fire haptics on every meaningful action: BreathingExercise.tsx:60 (
"void haptic('medium');" per phase), PanicOverlay.tsx:43, BoardBound question
.tsx:134-139 (success/error on answer reveal).
- fix: Add a small Haptics enum
wrapping UIImpactFeedbackGenerator (.light on play/pause, .medium on record sta
rt/stop and resume) and UINotificationFeedbackGenerator (.success when a filing
saves), called from the same action closures; keep it best-effort like the vete
ran service.

FINDING 5
- dimension: 6
- severity: should
- target: retold
/Retold/Screens/SettingsView.swift:68  quote: "/// Builds the manifest on the m
ain actor, then zips off it. Export is never gated."
- evidence: startExport()
fetches every Period, Episode, Capture and Question and builds ExportManifest (
lines 73-79) synchronously on the main actor; only the zip is detached (lines 8
9-92). On a large library, opening Settings and tapping Export freezes the UI f
or the entire manifest build - the exact "first-frame work on the main thread" 
hazard in reverse.
- fix: Move the four fetches and ExportManifest.build into 
the existing Task.detached block (modelContext is not thread-bound; pass the bu
ilt library value across), leaving only exportState assignments on the main act
or.

FINDING 6
- dimension: 6
- severity: polish
- target: retold/Retold/S
creens/HomeView.swift:293  quote: "episode.captures.sorted { (a: Capture, b: Ca
pture) -> Bool in"
- veteran counterpart: BoardBound/boardbound/app/quiz/quest
ion.tsx:72  quote: "const todayTotal = useMemo(() => getTodayAnsweredCount(), [
isAnswered]);"
- evidence: EpisodeRow.firstCapture sorts episode.captures on e
very body evaluation of every row, and EpisodeView.sortedCaptures (EpisodeView.
swift:32-36) re-sorts on every body pass - O(n log n) per row in a long list, p
aid during scrolling and on every playback tick that re-renders rows.
- fix: S
ort once: expose a stored/cached ordered captures collection (or sort in the Sw
iftData fetch with SortDescriptor) and have EpisodeRow take the precomputed fir
st capture id instead of sorting in its body.

FINDING 7
- dimension: 2
- s
everity: polish
- target: retold/Retold/Screens/HomeView.swift:71  quote: "For
Each(Array(sections.enumerated()), id: \\.offset) { _, section in"
- evidenc
e: When the library has no episodes, HomeView still renders a Section per perio
d (seeded defaults) with zero episode rows and no designed empty message; the t
arget's other pages all use EmptyPage (PeopleView.swift:10-11, PeriodView.swif
t:14-15, ThemesView.swift:27-28) and EmptyPage's own doc comment says it exist
s so a page "never leaves a blank page".
- fix: When all sections are episode-
empty, render one EmptyPage-style ContentUnavailableView with the record action
, matching the house rule 12 pattern the rest of the app already follows.

FI
NDING 8
- dimension: 4
- severity: polish
- target: retold/Retold/Screens/Co
nfirmView.swift:220  quote: "Image(systemName: \"trash\")"
- veteran counter
part: wilderness/src/components/emergency/PanicOverlay.tsx:171  quote: "aria-la
bel=\"Restart breathing exercise\""
- evidence: The remove-typed-person and 
remove-typed-place buttons (ConfirmView.swift:217-221 and 266-270) are icon-onl
y with no .accessibilityLabel, so VoiceOver lands on an undifferentiated "Trash
" with no indication of which person/place is removed. The target itself knows 
the right pattern: PlayPauseButton sets .accessibilityLabel (HomeView.swift:285
); veterans label every icon-only control.
- fix: Add .accessibilityLabel("Rem
ove \(entityName(...))") (and a hint where useful) to both trash buttons.

F
INDING 9
- dimension: 7
- severity: polish
- target: retold/Retold/Screens/H
omeView.swift:130  quote: "Button(\"OK\") {}"
- veteran counterpart: retold/
Retold/Screens/HomeView.swift:136  quote: "Button(AppCopy.okButton, role: .canc
el) {}"
- evidence: The deleteFailed alert hard-codes "OK" two lines above the
same file's AppCopy.okButton, and the alert carries a title with no message - 
so a failed delete says something failed but not what to do. Every other alert 
in the excerpts uses AppCopy constants and a message.
- fix: Use AppCopy.okBut
ton for the deleteFailed alert and add a message string ("The recording could n
ot be deleted. Try again.") to AppCopy alongside the existing saveFailed messag
e.

FINDING 10
- dimension: 5
- severity: polish
- target: retold/Retold/S
creens/RecorderView.swift:69  quote: ".background(.yellow.opacity(0.3), in: Rou
ndedRectangle(cornerRadius: 8))"
- veteran counterpart: burn-wizard/app/src/st
yles/design-system.css:25  quote: "--primary: 174 76% 27%; /* Professional medi
cal teal */"
- evidence: The recorder paints literal .red (RecorderView.swift:
38) and .yellow.opacity(0.3) inline instead of named tokens; the veterans carry
whole measured token layers with per-surface contrast notes (design-system.css 
lines 19-24) and brand-accent utility classes (e.g. BreathingExercise.tsx:138).
HOUSE-STYLE rules themselves are not in the packet, so this is flagged on the v
eteran-basis only.
- fix: Move recorder red, warning surface, and corner radiu
s into named Color/ShapeStyle tokens (Asset catalog or a Color extension) so th
e R7 design pass and future screens have one source of truth.

FINDING 11
- 
dimension: 1
- severity: polish
- target: retold/Retold/RetoldApp.swift:66  q
uote: "switch coordinator.state.phase {"
- veteran counterpart: BoardBound/boa
rdbound/app/quiz/question.tsx:17  quote: "import Animated, { FadeInDown } from 
\"react-native-reanimated\";"
- evidence: Recorder<->Home swaps are hard cut
s with no transition, and ConfirmView shows Color.clear (ConfirmView.swift:54) 
between appear and load, a visible blank flash. Veterans animate every state ch
ange (BreathingExercise.tsx:150 "transition: `transform ${transitionSeconds}s e
ase-in-out`") and BoardBound reads a reduce-motion hook (question.tsx:19,44) to
gate it - Retold has no equivalent handling anywhere in the excerpts.
- fix: W
rap the phase switch in a low-key .transition(.opacity) inside a ZStack/transit
ion container and replace Color.clear with a ProgressView; read @Environment(\
\.accessibilityReduceMotion) and skip the animation when set.

## Notes on w
hat is not in packet

Apple doc URLs were not fetched (task restricted to thi
s file), so all evidence above is quoted code from the packet. AppCopy strings,
AudioPlayback, CaptureCoordinator, the recorder engine, Info.plist/orientation 
locks, and the ConfirmView tail (file(), skipSuggestions()) are not in packet a
nd were not scored.

## What the target already does well

The recorder sta
te machine is the strongest code here: single-flight capture IDs, never a secon
d capture, explicit interrupted/stopping/aborting phases, protected-data gating
, and journaled resume after kill (RecorderMachine.swift) - deeper than anythin
g the veteran excerpts show. State clarity elsewhere is close to the bar: disab
led File/Save/Stop buttons, a labeled "saving" state while the engine finalizes
, full empty-state coverage via EmptyPage, and delete flows that always confirm
before destroying data.'
)
StatusUpdate(
    context_usage=0.22198867797851562,
    token_usage=TokenUsage(
        input_other=15441,
        output=11074,
        input_cache_read=42752,
        input_cache_creation=0
    ),
    message_id='chatcmpl-Dtemgfrv2ADbLn5LKqdbet5J'
)
TurnEnd()
