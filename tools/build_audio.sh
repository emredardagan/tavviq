#!/bin/sh
# Regenerates every sound in Tavviq/Resources/Sounds.
set -e
cd "$(dirname "$0")/.."
TMP=$(mktemp -d)
python3 tools/gen_audio.py "$TMP"
OUT=Tavviq/Resources/Sounds
mkdir -p "$OUT"
rm -f "$OUT"/*.caf "$OUT"/*.m4a
for f in "$TMP"/*.wav; do
  name=$(basename "$f" .wav)
  if [ "$name" = "music" ]; then
    afconvert -f m4af -d aac -b 128000 "$f" "$OUT/$name.m4a"
  else
    afconvert -f caff -d LEI16 "$f" "$OUT/$name.caf"
  fi
done
rm -rf "$TMP"
ls -la "$OUT"
