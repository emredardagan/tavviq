#!/bin/sh
# Builds Tavviq for the simulator. Usage: tools/run_sim.sh <simulator-udid>
set -e
cd "$(dirname "$0")/.."
xcodebuild -project Tavviq.xcodeproj -scheme Tavviq -destination "id=$1" -derivedDataPath build/dd build 2>&1 | grep -E "error|BUILD" | sort -u
