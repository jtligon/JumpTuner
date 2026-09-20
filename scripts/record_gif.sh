#!/usr/bin/env bash
# record_gif.sh
#
# Boots a simulator, builds the app, launches it, records a screen capture,
# and converts the output to an animated GIF suitable for App Store marketing.
#
# Usage:
#   ./scripts/record_gif.sh [DEVICE_NAME] [DURATION_SECS] [OUTPUT_DIR]
#
# Defaults:
#   DEVICE_NAME   "iPhone 16 Pro"
#   DURATION_SECS 10
#   OUTPUT_DIR    fastlane/marketing
#
# Requirements:
#   - Xcode command-line tools (xcrun, simctl)
#   - ffmpeg  (brew install ffmpeg)
#   - The project must already be built; pass DERIVED_DATA_PATH env var or
#     let the script build it into /tmp/JumpTunerDerivedData.

set -euo pipefail

DEVICE_NAME="${1:-iPhone 16 Pro}"
DURATION="${2:-10}"
OUTPUT_DIR="${3:-fastlane/marketing}"
BUNDLE_ID="visceralorigami.JumpTuner"
SCHEME="JumpTuner"
DERIVED_DATA="${DERIVED_DATA_PATH:-/tmp/JumpTunerDerivedData}"

mkdir -p "$OUTPUT_DIR"

# ── 1. Resolve simulator UDID ────────────────────────────────────────────────
echo "▸ Looking for simulator: $DEVICE_NAME"
SIM_ID=$(
  xcrun simctl list devices available -j \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data['devices'].items():
    for d in devices:
        if '${DEVICE_NAME}' in d['name'] and d['isAvailable']:
            print(d['udid'])
            sys.exit(0)
sys.exit(1)
" 2>/dev/null || true
)

if [ -z "$SIM_ID" ]; then
  echo "✗ No available simulator named '${DEVICE_NAME}' found."
  echo "  Run: xcrun simctl list devices available"
  exit 1
fi
echo "  Found: $SIM_ID"

# ── 2. Build for simulator (skip if app already built) ───────────────────────
APP_PATH=$(find "$DERIVED_DATA" -name "JumpTuner.app" -path "*/Debug-iphonesimulator/*" 2>/dev/null | head -1 || true)

if [ -z "$APP_PATH" ]; then
  echo "▸ Building JumpTuner for simulator…"
  xcodebuild \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=$SIM_ID" \
    -derivedDataPath "$DERIVED_DATA" \
    -configuration Debug \
    build \
    CODE_SIGNING_ALLOWED=NO \
    | xcpretty --simple 2>/dev/null || true
  APP_PATH=$(find "$DERIVED_DATA" -name "JumpTuner.app" -path "*/Debug-iphonesimulator/*" | head -1)
fi

if [ -z "$APP_PATH" ]; then
  echo "✗ Could not locate JumpTuner.app after build."
  exit 1
fi
echo "▸ App: $APP_PATH"

# ── 3. Boot simulator ────────────────────────────────────────────────────────
STATE=$(xcrun simctl list devices -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data['devices'].items():
    for d in devices:
        if d['udid'] == '${SIM_ID}':
            print(d['state'])
            sys.exit(0)
")

if [ "$STATE" != "Booted" ]; then
  echo "▸ Booting simulator…"
  xcrun simctl boot "$SIM_ID"
  # Wait for the simulator to become ready
  for i in $(seq 1 30); do
    sleep 1
    ST=$(xcrun simctl list devices -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
for rt, devs in data['devices'].items():
    for d in devs:
        if d['udid'] == '${SIM_ID}':
            print(d['state']); sys.exit(0)
" 2>/dev/null || echo "Unknown")
    [ "$ST" = "Booted" ] && break
  done
fi
echo "▸ Simulator is booted"

# ── 4. Install app ───────────────────────────────────────────────────────────
echo "▸ Installing app…"
xcrun simctl install "$SIM_ID" "$APP_PATH"

# ── 5. Record video while launching the app ───────────────────────────────────
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
MOV_PATH="$OUTPUT_DIR/jump_preview_${TIMESTAMP}.mov"
GIF_PATH="$OUTPUT_DIR/jump_preview_${TIMESTAMP}.gif"
PALETTE_PATH="/tmp/palette_${TIMESTAMP}.png"

echo "▸ Recording ${DURATION}s of screen…"
xcrun simctl io "$SIM_ID" recordVideo --codec=h264 "$MOV_PATH" &
RECORD_PID=$!

# Short pause so the recorder is ready before the app launches
sleep 0.5

xcrun simctl launch "$SIM_ID" "$BUNDLE_ID" >/dev/null

sleep "$DURATION"

# Terminate the recording gracefully
kill -SIGINT "$RECORD_PID" 2>/dev/null || true
wait "$RECORD_PID" 2>/dev/null || true

echo "▸ Video saved: $MOV_PATH"

# ── 6. Convert to GIF ────────────────────────────────────────────────────────
if ! command -v ffmpeg &>/dev/null; then
  echo "⚠  ffmpeg not found — skipping GIF conversion."
  echo "   Install with: brew install ffmpeg"
  echo "   Then convert manually:"
  echo "     ffmpeg -i '$MOV_PATH' -vf 'fps=20,scale=390:-1:flags=lanczos,palettegen' palette.png"
  echo "     ffmpeg -i '$MOV_PATH' -i palette.png -lavfi 'fps=20,scale=390:-1:flags=lanczos[x];[x][1:v]paletteuse' '$GIF_PATH'"
  exit 0
fi

echo "▸ Generating palette…"
ffmpeg -y -i "$MOV_PATH" \
  -vf "fps=20,scale=390:-1:flags=lanczos,palettegen=stats_mode=diff" \
  "$PALETTE_PATH" 2>/dev/null

echo "▸ Converting to GIF…"
ffmpeg -y -i "$MOV_PATH" -i "$PALETTE_PATH" \
  -lavfi "fps=20,scale=390:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
  "$GIF_PATH" 2>/dev/null

rm -f "$PALETTE_PATH"

echo "✓ GIF saved: $GIF_PATH"
