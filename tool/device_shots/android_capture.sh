#!/usr/bin/env bash
# Capture splash, loaded app, and launcher shots on an already-booted emulator.
# Usage: android_capture.sh <api-level>
set -euo pipefail

API="${1:?api level}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/shots/android-api${API}"
APK="${APK_PATH:-$ROOT/build/app/outputs/flutter-apk/app-debug.apk}"
PKG="com.dusk.saintstrivia.saints_trivia_flutter"
ACT="$PKG/.MainActivity"
HOLD_SECONDS="${HOLD_SECONDS:-8}"
mkdir -p "$OUT"
NOTES="$OUT/notes.txt"
: >"$NOTES"

log() { echo "$*" | tee -a "$NOTES"; }

adb wait-for-device
adb shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 1; done'
log "emulator booted (api request $API, release $(adb shell getprop ro.build.version.release | tr -d '\r'))"

if [[ ! -f "$APK" ]]; then
  log "missing apk at $APK"
  exit 1
fi
adb install -r "$APK"
log "installed $APK"

cap() {
  local name="$1"
  adb exec-out screencap -p >"$OUT/$name"
  log "saved $name ($(wc -c <"$OUT/$name") bytes)"
}

screen_size() {
  adb shell wm size | tr -d '\r' | awk -F '[ x:]' '/Physical size/{w=$(NF-1); h=$NF} END{print w, h}'
}

swipe_up() {
  read -r width height <<<"$(screen_size)"
  local cx=$((width / 2))
  adb shell input swipe "$cx" $((height * 3 / 4)) "$cx" $((height / 5)) 250
}

night() {
  adb shell cmd uimode night "$1"
  sleep 2
}

capture_run() {
  local night_mode="$1"
  local label="$2"
  adb shell am force-stop "$PKG" || true
  night "$night_mode"
  # A screencap loop made System UI show an ANR over the splash. One recording
  # covers the native hold and the Flutter overlay without poking the display.
  adb shell settings put global hide_error_dialogs 1 || true
  adb shell am broadcast -a android.intent.action.CLOSE_SYSTEM_DIALOGS >/dev/null 2>&1 || true
  local remote="/sdcard/splash-${label}.mp4"
  adb shell rm -f "$remote" || true
  local seconds=$((HOLD_SECONDS * 2 + 15))
  if (( seconds > 180 )); then
    seconds=180
  fi
  adb shell screenrecord --time-limit "$seconds" --bit-rate 8000000 "$remote" >/dev/null 2>&1 &
  local rec_pid=$!
  sleep 1
  adb shell am start -n "$ACT"
  log "started $label (screenrecord ${seconds}s)"
  wait "$rec_pid" || log "screenrecord exited $?"
  adb pull "$remote" "$OUT/splash-${label}.mp4"
  adb shell rm -f "$remote" || true
  if ! command -v ffmpeg >/dev/null; then
    log "ffmpeg is required to pull frames out of the recording"
    exit 1
  fi
  local burst="$OUT/burst-${label}"
  mkdir -p "$burst"
  ffmpeg -y -i "$OUT/splash-${label}.mp4" -vf fps=2 "$burst/%03d.png" >>"$NOTES" 2>&1
  local n
  n=$(find "$burst" -name '*.png' | wc -l)
  if (( n < 1 )); then
    log "no frames extracted for $label"
    exit 1
  fi
  cp "$burst/001.png" "$OUT/launch-${label}.png"
  copy_at() {
    local at="$1"
    local dest="$2"
    local idx=$((at * 2 + 1))
    if (( idx > n )); then idx=$n; fi
    if (( idx < 1 )); then idx=1; fi
    local frame
    frame="$(printf '%s/%03d.png' "$burst" "$idx")"
    cp "$frame" "$dest"
    log "copied $frame to $(basename "$dest") (about ${at}s, $n frames)"
  }
  copy_at $((HOLD_SECONDS / 2)) "$OUT/mid-${label}.png"
  copy_at $((HOLD_SECONDS + 10)) "$OUT/loaded-${label}.png"
  copy_at $((HOLD_SECONDS * 2 + 5)) "$OUT/settled-${label}.png"
}

capture_run no light
capture_run yes dark

adb shell am force-stop "$PKG" || true
night no
adb shell input keyevent KEYCODE_HOME
sleep 2
cap "launcher-home.png"
swipe_up || true
sleep 2
cap "launcher-drawer.png"
adb shell uiautomator dump /sdcard/uidump.xml >/dev/null || true
adb shell cat /sdcard/uidump.xml >"$OUT/launcher-dump.xml" || true
if grep -q 'text="Trivia"' "$OUT/launcher-dump.xml"; then
  log "launcher dump contains the Trivia label"
else
  log "launcher dump does not contain text Trivia"
fi

if [[ "$API" -ge 33 ]]; then
  log "attempting themed icons"
  {
    echo "overlay packages before: $(adb shell settings get secure theme_customization_overlay_packages | tr -d '\r')"
    echo "available icon overlays:"
    adb shell cmd overlay list | tr -d '\r' | grep -i 'theme.icon' || true
    adb shell settings put secure theme_customization_overlay_packages \
      '{"android.theme.customization.icon_pack":"com.android.theme.icon_pack.circular.android"}'
    echo "overlay packages after: $(adb shell settings get secure theme_customization_overlay_packages | tr -d '\r')"
  } | tee -a "$NOTES"
  adb shell am force-stop com.android.launcher3 >/dev/null 2>&1 || true
  adb shell am force-stop com.google.android.apps.nexuslauncher >/dev/null 2>&1 || true
  sleep 3
  adb shell input keyevent KEYCODE_HOME
  sleep 2
  swipe_up || true
  sleep 2
  cap "launcher-themed.png"
  adb shell uiautomator dump /sdcard/uidump-themed.xml >/dev/null || true
  adb shell cat /sdcard/uidump-themed.xml >"$OUT/launcher-themed-dump.xml" || true
else
  log "skipping themed icons: API $API is below Android 13"
fi

log "done"
required=(launch-light.png loaded-light.png launch-dark.png loaded-dark.png launcher-home.png launcher-drawer.png)
for name in "${required[@]}"; do
  path="$OUT/$name"
  if [[ ! -s "$path" ]]; then
    log "missing $name"
    exit 1
  fi
  bytes=$(wc -c <"$path")
  if [[ "$bytes" -lt 10000 ]]; then
    log "$name is only $bytes bytes"
    exit 1
  fi
done
