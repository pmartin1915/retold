# Handoff: retold-listen lane, 2026-11-12

READ FIRST
- PR #37 (`listen/hardening`, head 4363862, last CI commit 73f2f65): Build & Test and the Listening harness are green on 73f2f65. App Store Screenshots was still running at handoff.
- Done:
  - Step 1 diagnosis: docs/research/LISTEN-DIAGNOSIS-2026-11-12.md. Top finding: a completed live run is saved as `.complete`, so the file pass never runs.
  - Step 2 harness: harness/ and listen-harness.yml. It compiles and runs, but no CI host has a working recognizer (docs/research/LISTEN-HARNESS-PROBE-2026-11-12.md).
  - The harness also runs on the phone as a hidden Debug/TestFlight-only "Listening self-test" (Settings). It compares the tunings current/steady/fast and shares JSON. Score it with `python3 harness/score.py report.json`.
  - Step 4: capture stats (counts and timings, no words) on test builds, shared from the same screen.
- The app still ships `ListenTuning.shipping = .current`. Nothing in its behavior changed except the stats record on test builds.
- Waiting: the boss picks how build A reaches TestFlight. Then Perry runs the self-test (~15 min) and shares the report and the capture stats.
- Next: score the report. Flip `ListenTuning.shipping` and decide file-pass-as-final from the numbers (ai/IDEAS.md 2026-11-12). Then Sol review (step 5), done report to boss. Never merge or run deploy.yml.
