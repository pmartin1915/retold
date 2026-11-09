# comeup adjudication: Retold, 2026-11-09 (run 2)

Reviewers held: Sonnet [x]  Kimi [x]  Sol [x] (Sol on account pmartin18551998, codex exec read-only, packet inline via stdin).
Sonnet and Kimi read packet.md from disk (not pasted inline), each in a fresh context, told to open nothing else.
Raw answers: review-sonnet.md, review-kimi.md, review-sol.md. S = Sonnet, K = Kimi, O = Sol.

Seat scores (dimensions 1-8): S 2/2/3/2/1/2/2/2, K 2/2/3/2/1/2/3/2, O 2/1/3/2/1/1/2/2.

Fabrication check: every target quote and line number cited below was checked against the code at origin/main (a5d618f).
One mis-citation, none fabricated: K F1 credits "mb-3 w-full rounded-xl bg-brand-600 ..." to BrandedSplash.tsx:73, but it is
ErrorBoundary.tsx:73. S and O cite the same finding correctly.

| ID | Dim | Finding (merged) | Said by | Verified in code? | Verdict | Reason | PR / Deferred |
|---|---|---|---|---|---|---|---|
| C1 | 5 | Record a memory is a plain list row; it should be the one prominent, accent-filled action in thumb reach | S K O | yes HomeView.swift:41 | accepted | Apple Buttons quote + HOUSE-STYLE rule 11; screenshot S1 | P2 visual |
| C2 | 1/4/5 | Recorder: 16 pt static dot, title2 clock, ~60% empty screen, Stop is a text link | S K O | yes RecorderView.swift:50-55, 91 | accepted | screenshot S3; Stop is the most time-pressured control | P2 visual |
| C3 | 5 | No brand accent anywhere (Retold has no AccentColor asset; system blue) | O (S, K via S1) | yes Assets.xcassets has only AppIcon | accepted | BRAND.md: Retold is on the family line, terracotta #AD512B light / #E07A50 dark; StoryCue ships the same tokens | P2 visual |
| C4 | 8 | Confirm suggestion rows squeeze the user's words to 3 lines (title row and period row) | S K O | yes ConfirmView.swift:118-131, 326-340 | accepted | screenshot S4 | P3 layout |
| C5 | 8 | Story page: five question offers push the recordings and transcript below the fold | S K O | yes EpisodeView.swift:19 before :23 | accepted (reorder) | screenshot S5; XCUI needed to scroll (PR #26). Collapsing or tabbing the questions is Perry's pick (V5) | P3 layout |
| C6 | 8 | Story title truncates in the large nav title | S O | yes EpisodeView.swift:29 | accepted | screenshot S5 | P3 layout |
| C7 | 8 | Home: five browse links sit above the user's own stories | S O | yes HomeView.swift:64-71 | accepted | screenshot S2 | P3 layout |
| C8 | 2 | Empty Home (no stories) shows bare link list, no designed state | S K | yes HomeView.swift:64 always built | accepted | run 1 deferral C18; EmptyPage pattern exists | P3 layout |
| C9 | 2 | File it failure is silent (empty catch) | S O | yes ConfirmView.swift:500-504 | accepted | most important commit action | P1 #27 |
| C10 | 2 | Startup failure is bare text, no Retry | S K O | yes RetoldApp.swift:13-14, :23 guard | accepted | run 1 deferral C17 | P1 #27 |
| C11 | 2 | Playback failure is silent (dead Play tap) | K O | yes AudioPlayback.swift:29 comment, catch calls stop() | accepted | "no dead taps" | P4 playback |
| C12 | 6 | Whole story page re-renders 4x/s during playback (body reads currentTime; canPlay does fileExists per capture) | S | yes EpisodeView.swift:69, 85; AudioPlayback.swift:23-24, 0.25 s loop | accepted | lone finding, verified | P4 playback |
| C13 | 4/8 | Player row and EpisodeRow HStacks crush at accessibility sizes | S K | yes EpisodeView.swift:81 | accepted | run 1 deferral (Dynamic Type row layout) | P4 playback (player row); P3 (confirm rows) |
| C14 | 4 | "Use this"/"Not this" repeated with no object for VoiceOver | S | yes ConfirmView.swift:334-339 | accepted | lone finding, verified; screenshot test's "Use this" query must become a prefix match | P3 layout |
| C15 | 4 | OfferRow "Answer now / Not this one" and choice buttons have no 44 pt frame | K | yes OfferRow.swift:21-32 | accepted | lone finding, verified; HOUSE-STYLE rule 4 | P3 layout |
| C16 | 1 | Confirm draft mutations jump with no animation | S | yes ConfirmView.swift mutateDraft | accepted | lone, verified; Reduce Motion gated | P3 layout |
| C17 | 7 | Start-failure alert shows raw error text after "Details: " | S K O | yes HomeView.swift:139, CaptureCoordinator.swift:134, 219 | deferred | Retold has no crash reporting (M4 = 0); PR #19 added this detail on purpose and it is the only device diagnostic. Remove it once a log/crash channel exists | IDEAS |
| C18 | 6 | Export fetch and manifest build on the main actor | K O | yes SettingsView.swift:70-88 | deferred | already deferred in run 1 P4: needs a ModelActor and Instruments numbers | IDEAS |
| C19 | 1 | Press states / spring on custom buttons | S K | yes .plain rows | Perry's pick | V1 below | waiting |
| C20 | 1 | Staggered list entrance | K | n/a (new) | Perry's pick | V6 below | waiting |
| C21 | 2 | Skeleton placeholders instead of bare spinners | K (O, S as feature) | yes ConfirmView.swift:53-55 | Perry's pick | V4 below | waiting |
| C22 | harness | AX5 screenshot check in the harness | K | n/a | accepted | FlowTests with a large content size category | P3 layout |
| C23 | M4 | No crash reporting | K (feature 5) | yes (probe M4 = 0) | deferred | outside the rubric's UI scope; needs a vendor choice and privacy manifest change | IDEAS |

## Veteran features to borrow (merged; Perry picks, multiSelect)

| V | Feature | Veteran file:line | Said by | Retold version | Effort |
|---|---|---|---|---|---|
| V1 | Spring press + selection haptic on tappable rows and Use this / Not this | BoardBound/components/question/OptionButton.tsx:64, :71 | S K O | one shared ButtonStyle: 0.97 spring on press, selection haptic, off under Reduce Motion | S |
| V2 | "Filed" confirmation pill with a VoiceOver announcement | BoardBound/components/game/EarnToast.tsx:28 | S K O | after File it, a short "Filed under <title>" capsule on Home, announced, static under Reduce Motion | S |
| V3 | Branded launch / loading view with the mark | BoardBound/components/BrandedSplash.tsx:16-24 | S K O | the Retold mark + name on the terracotta line instead of a bare ProgressView while storage opens (no timed delay) | S |
| V4 | Content-shaped loading placeholders | BoardBound/components/ui/Skeleton.tsx:14-23 | S K O | Transcribing rows and the confirm sheet's wait show redacted placeholder lines, static under Reduce Motion | S-M |
| V5 | Story page: questions opt-in (segmented Recordings / Questions, or one collapsed "Questions (n)" row) | burn-wizard/app/src/components/trainer/TrainerFeedback.tsx:134-158 | S O (K: collapse) | recordings first either way (accepted C5); this picks how the questions hide | M |
| V6 | Staggered list entrance | BoardBound/components/ui/StaggeredEntrance.tsx:36-39 | K | Home and Period rows fade up with a short stagger, static under Reduce Motion | S |

Recommendation: V1, V2, V3 (small, all three seats proposed them, and they are what makes the veterans feel finished). V5 as the collapsed row (cheaper than tabs). V4 and V6 later.

## PR plan (themes, smallest first)
- #26 harness: UI assertions + scrubber question (folds #25)
- P1 #27 state clarity: C9, C10 + FlowTests harness
- P2 visual: C1, C2, C3 (AccentColor/OnAccent + primaryAction from StoryCue's DesignTokens, recorder elevation)
- P3 layout: C4-C8, C14-C16, C22
- P4 playback: C11, C12, C13 (player row)
- P5 (after Perry's pick): chosen V items
