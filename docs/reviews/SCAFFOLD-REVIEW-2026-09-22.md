# Scaffold review, 2026-09-22 -- project.yml, build.yml, deploy.yml, app + test skeleton

Pre-commit cross-family review of the Claude-authored week-0 scaffold, forked from
StoryCue's own CI-green scaffold with the Duo path removed. **Kimi**
(`pal clink cli_name=kimi role=codereviewer`, 223 s, `return_code 0`, 16 tool calls;
cross-checked against the StoryCue sibling via `Compare-Object` and against
`storycue/docs/reviews/SCAFFOLD-REVIEW-2026-09-21.md`'s prior findings). No Mac exists,
so this review plus the first CI run on `xcode-27` are the only execution the scaffold
gets before it is pushed.

**No blocking findings.** All three recommendations were Low severity and cosmetic/
hardening; all three accepted and applied before commit:

| # | Kimi | Verdict |
|---|---|---|
| 1 | **Low.** `build.yml`/`deploy.yml` install XcodeGen from `releases/latest`, which drifts; pin a tag. | **ACCEPT** -- pinned to `2.46.0` (same version the storycue sibling's review verified live) in both workflows. |
| 2 | **Low.** `deploy.yml`'s upload condition compared the typed `workflow_dispatch` boolean input against the string `'true'` via `github.event.inputs.upload`; works today but not immune to runner-context changes. | **ACCEPT** -- switched to `inputs.upload == true`. |
| 3 | **Low.** `RetoldTests`' Info.plist hardcoded `CFBundleShortVersionString`/`CFBundleVersion` while the app target used the `$(MARKETING_VERSION)`/`$(CURRENT_PROJECT_VERSION)` variables -- harmless now, silently divergent later. | **ACCEPT** -- test target now references the same variables. |

Checked clean by Kimi, recorded so the next session does not re-ask: `TEST_HOST`/
`BUNDLE_LOADER` present and correct (the XcodeGen #408-class gap StoryCue's own review
caught is already closed here); `ENABLE_TESTABILITY` + `SWIFT_ACTIVE_COMPILATION_CONDITIONS:
DEBUG` both set, so `@testable import Retold` compiles; the placeholder test target
builds and runs standalone against `RetoldApp.swift` with zero real app code; Duo removal
is complete -- diffed against the StoryCue sibling, only renames and intentional
removals (Duo gate step, `STORYCUE_DUO_CONDITIONS`, `StoryCueDuoTests` target, landscape
orientations, camera/photo usage strings), nothing left dangling; iOS 26.0 deployment
target has no conflict with the `xcode-27` runner's SDK 27 image; all three YAML files
parse; the `sort -V` line (already adjudicated fine on macOS BSD sort in the sibling
review) carried forward unchanged; `PrivacyInfo.xcprivacy` correctly placed inside
`Retold/` for XcodeGen to pick up as a resource, `CA92.1` is the correct reason code.

**Watch item, not a defect (carried over from the sibling review):** whether `xcrun
altool --upload-app` (`deploy.yml`) still ships in Xcode 27 is unverified. Decide the
fallback (`notarytool`-era tooling / Transporter) at the first real deploy, not now --
same call the storycue sibling made.
