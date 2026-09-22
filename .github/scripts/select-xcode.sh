#!/usr/bin/env bash
# Pick Xcodes by build number and SDK, not by how their folder names sort.
#
# Why: the xcode-27 runner image rolls out gradually, so one run landed on an image with
# Xcode_27.2_beta.app and the next on one with only Xcode_27_Release_Candidate.app
# (runs 35759964133 / 35769450879). `ls | sort -V | tail -1` handed the baseline lane -- and
# deploy -- a beta on some runs. Beta Xcodes may upload to TestFlight but NOT to App Review.
#
# Fails closed: the baseline/deploy Xcode must be one whose build is on the allowlist below.
# Update ASC_REVIEW_XCODE_BUILDS only after Apple's App Store Connect release notes approve
# another toolchain for App Store submission (space-separated build numbers).
#
# Emits (to this shell when sourced, and to $GITHUB_ENV):
#   RELEASE_XCODE  allowlisted Xcode (newest version among allowlisted builds)
#   DUO_XCODE      newest Xcode of any channel whose iphoneos SDK is >= 27.1 (empty if none)
set -euo pipefail

ASC_REVIEW_XCODE_BUILDS="${ASC_REVIEW_XCODE_BUILDS:-27A266a}"

ROWS="$(
  for link in /Applications/Xcode*.app; do
    [ -e "$link" ] || continue
    (cd -P "$link" && pwd -P)   # resolves Xcode.app-style symlinks; no realpath on the runner
  done | LC_ALL=C sort -u |
  while IFS= read -r app; do
    dev="$app/Contents/Developer"
    meta="$(DEVELOPER_DIR="$dev" xcodebuild -version 2>/dev/null)" || continue
    version="$(printf '%s\n' "$meta" | awk '/^Xcode / { print $2 }')"
    build="$(printf '%s\n' "$meta" | awk '/^Build version / { print $3 }')"
    sdk="$(DEVELOPER_DIR="$dev" xcrun --sdk iphoneos --show-sdk-version 2>/dev/null)" || continue
    [ -n "$version" ] && [ -n "$build" ] && [ -n "$sdk" ] || continue
    printf '%s\t%s\t%s\t%s\n' "$version" "$build" "$sdk" "$app"
  done
)"

{
  echo "## Xcodes on this image"
  echo "| app | version | build | iphoneos SDK | App Review allowlisted |"
  echo "|---|---|---|---|---|"
  printf '%s\n' "$ROWS" | while IFS=$'\t' read -r v b s a; do
    [ -n "$a" ] || continue
    case " $ASC_REVIEW_XCODE_BUILDS " in *" $b "*) ok=yes ;; *) ok=no ;; esac
    echo "| $(basename "$a") | $v | $b | $s | $ok |"
  done
} | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"

RELEASE_XCODE="$(
  printf '%s\n' "$ROWS" |
  awk -F '\t' -v allow=" $ASC_REVIEW_XCODE_BUILDS " 'index(allow, " " $2 " ") > 0 { print $1 "\t" $4 }' |
  LC_ALL=C sort -t $'\t' -k1,1V | tail -1 | cut -f2-
)"
if [ -z "$RELEASE_XCODE" ]; then
  echo "No App-Review-allowlisted Xcode (builds: $ASC_REVIEW_XCODE_BUILDS) on this image; refusing to build baseline/deploy on anything else." >&2
  exit 1
fi

DUO_XCODE="$(
  printf '%s\n' "$ROWS" |
  awk -F '\t' '{
    split($3, v, ".");
    if ((v[1]+0) > 27 || ((v[1]+0) == 27 && (v[2]+0) >= 1)) print $3 "\t" $1 "\t" $4
  }' |
  LC_ALL=C sort -t $'\t' -k1,1V -k2,2V | tail -1 | cut -f3-
)"

{
  echo ""
  echo "- Baseline / deploy Xcode: **$(basename "$RELEASE_XCODE")**"
  echo "- Duo-lane Xcode (iphoneos SDK >= 27.1): **$([ -n "$DUO_XCODE" ] && basename "$DUO_XCODE" || echo none)**"
} | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"

if [ -n "${GITHUB_ENV:-}" ]; then
  {
    echo "RELEASE_XCODE=$RELEASE_XCODE"
    echo "DUO_XCODE=$DUO_XCODE"
  } >> "$GITHUB_ENV"
fi
