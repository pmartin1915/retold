#!/usr/bin/env bash
# Generates the transcription harness fixtures with macOS `say` (CI only; this needs macOS).
# Each fixture: <out>/<name>.wav, 48 kHz Float32 mono like the iPhone mic, so the app's live
# path takes the same converter branch as on device; <out>/<name>.txt, the reference words
# (the script with [[slnc N]] pause commands removed).
# Usage: harness/make-fixtures.sh <out dir>
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="$1"
mkdir -p "$out"
voices="$(say -v '?' | awk '{print $1}')"
echo "Voices on this runner (English ones):"
say -v '?' | grep -E 'en_|en-' || true

grep -v '^#' "$here/fixtures.tsv" | while IFS=$'\t' read -r name script candidates rate; do
  [ -n "$name" ] || continue
  voice=""
  IFS=',' read -ra wanted <<< "$candidates"
  for v in "${wanted[@]}"; do
    if printf '%s\n' "$voices" | grep -qx "$v"; then voice="$v"; break; fi
  done
  if [ -z "$voice" ]; then
    voice="$(say -v '?' | grep -E 'en_US|en-US' | head -1 | awk '{print $1}')"
  fi
  if [ -z "$voice" ]; then echo "No English voice for $name"; exit 1; fi
  say -v "$voice" -r "$rate" -f "$here/scripts/$script.say" \
      -o "$out/$name.wav" --file-format=WAVE --data-format=LEF32@48000
  sed -E 's/\[\[[^]]*\]\]//g' "$here/scripts/$script.say" | tr -s ' \n' ' ' | sed -E 's/^ +| +$//g' > "$out/$name.txt"
  printf '%s\tvoice=%s\trate=%s\t%s\n' "$name" "$voice" "$rate" "$(afinfo "$out/$name.wav" | grep -E 'duration|Data format' | tr '\n' ' ')"
done
