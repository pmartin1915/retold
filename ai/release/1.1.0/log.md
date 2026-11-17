# Retold 1.1.0 release-train run log

Run: release-train retold 1.1.0 (perrypc, started 2026-11-16, submitted 2026-11-17). Perry's go: "submit Retold" (2026-11-16).

## Hold gate
1. Apple open request: none. The three Oct 20-21 submissions are COMPLETE; the 1.0 record was never filed (parked 2026-11-10).
2. Device check: Perry tried TestFlight 22.1 on his phone, 2026-11-17: "yes they work great" (Better transcripts). Cleared.
3. Clinical diff: n/a (Retold is not clinical).
4. Money: retold is PUBLIC (GitHub Actions free). No build was dispatched in this run; build 22.1 came from deploy run 43956041105.

## Checklist
1. Version: no live version (first release). The unfiled 1.0 record (81636e8b) was renamed to 1.1.0; the parked 1.0 (14.1) was never submitted.
2. Code: PR #37 (abf6cf7) and PR #40 (48516dd) merged to main, CI green (see lane retold-whisper report).
3. Build: release SHA 48516dd, deploy run 43956041105, ASC build 88fd3adb-c0ab-4aee-aaf2-2866cee373a5, build 22.1, VALID, What to Test 240 chars.
3a. Simulator: listening harness (with Whisper on CPU) green on the merged line; no Codemagic sim job for this app.
4. Version record: build 22.1 attached in place of 14.1. First release, so What's New is empty. Description updated with a Better transcripts section. Screenshots replaced with the CI 1.1.0 set (5, APP_IPHONE_67, each looked at). Privacy policy updated and live (martinapps-site 100d4e5).
5. Review notes: rewritten (2757 chars) for the optional Whisper download (Hugging Face model files, no user data sent) and suggestions off by default. Device video attached: retold-1.1.0-review.mov (Perry's 59 s recording on 22.1, re-encoded to 1.1 MB), attachment f543b270-ec89-4d19-96dc-16d54c879723, COMPLETE.
6. Age rating: socialMedia=false (appInfo 969e5cc7).
6b. New App Compliance forms (China mainland), which blocked the first item POST with 409 NEW_APP_SUBMISSION_BLOCK: Security Assessment = No, AI Generated or Synthetic Content = No (Perry approved 2026-11-17; on-device speech-to-text generates no content). Both Active.
7. releaseType AFTER_APPROVAL.
8. Read-only check: asc-check.txt, no FAIL lines.
9. Submit: reused empty review submission 38f3853a-af0a-4839-a8b3-27296b614f27 (1.1.0's earlier draft item was removed 2026-11-16 to edit screenshots). Item MzhmMzg1M2EtYWYwYS00ODM5LWE4YjMtMjcyOTZiNjE0ZjI3fDZ8ODkyNTE1NTUy (version 81636e8b only). submitted:true at 2026-11-17T22:48:15Z.
10. Confirmed: WAITING_FOR_REVIEW, AFTER_APPROVAL, build 22.1 (asc-check.txt).
11. STATE updated in this commit.
12. Live: pending approval; Store Watch confirms.
