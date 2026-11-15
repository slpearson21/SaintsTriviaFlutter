#!/usr/bin/env bash
# Capture launch, loaded, and home-screen shots on a booted iOS Simulator.
# Expects a debug simulator build of Runner.app already on disk.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/shots/ios"
APP="${APP_PATH:-$ROOT/build/ios/iphonesimulator/Runner.app}"
BUNDLE_ID="${BUNDLE_ID:-com.dusk.saintstrivia.saintsTriviaFlutter}"
# Native splash stays up through the bank load plus this hold (compiled in).
HOLD_SECONDS="${HOLD_SECONDS:-8}"
mkdir -p "$OUT"
NOTES="$OUT/notes.txt"
: >"$NOTES"

log() { echo "$*" | tee -a "$NOTES"; }

pick_device() {
  python3 - <<'PY'
import json, subprocess, sys
raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"])
data = json.loads(raw)
best = None
for runtime, devices in data.get("devices", {}).items():
    if "iOS-" not in runtime:
        continue
    version = runtime.split("iOS-")[-1].replace("-", ".")
    parts = version.split(".")
    try:
        major = int(parts[0])
        minor = int(parts[1]) if len(parts) > 1 else 0
    except ValueError:
        continue
    if major < 18:
        continue
    for device in devices:
        if not device.get("isAvailable", True):
            continue
        name = device.get("name", "")
        if "iPhone" not in name:
            continue
        bonus = 0
        if "Pro" in name and "Max" not in name:
            bonus = 3
        elif "Pro Max" in name:
            bonus = 2
        elif name.startswith("iPhone"):
            bonus = 1
        rank = (major, minor, bonus, name)
        if best is None or rank > best[0]:
            best = (rank, device["udid"], name, version)
if best is None:
    sys.exit("No available iPhone simulator on iOS 18 or later")
print(f"{best[1]}\t{best[2]}\t{best[3]}")
PY
}

shot() {
  local name="$1"
  xcrun simctl io "$UDID" screenshot "$OUT/$name"
  log "saved $name ($(wc -c <"$OUT/$name") bytes)"
}

set_appearance() {
  local mode="$1"
  if xcrun simctl ui "$UDID" appearance "$mode"; then
    log "appearance set to $mode"
  else
    log "appearance $mode failed"
    return 1
  fi
  sleep 2
}

IFS=$'\t' read -r UDID DEVICE_NAME DEVICE_IOS <<<"$(pick_device)"
log "simulator: $DEVICE_NAME (iOS $DEVICE_IOS) $UDID"
xcrun simctl boot "$UDID" || log "boot returned non-zero (often already booted)"
xcrun simctl bootstatus "$UDID" -b
log "booted"

if [[ ! -d "$APP" ]]; then
  log "missing app at $APP"
  exit 1
fi
xcrun simctl install "$UDID" "$APP"
log "installed $APP"

# Put Trivia on the first home-screen page when the icon state is a plain list.
place_icon() {
  local spring="$HOME/Library/Developer/CoreSimulator/Devices/$UDID/data/Library/SpringBoard"
  local plist="$spring/IconState.plist"
  if [[ ! -f "$plist" ]]; then
    log "IconState.plist not found at $plist"
    ls -la "$spring" >>"$NOTES" 2>&1 || true
    return 0
  fi
  python3 - "$plist" "$BUNDLE_ID" "Trivia" <<'PY' | tee -a "$NOTES"
import plistlib, sys
path, bundle, name = sys.argv[1:]
with open(path, "rb") as handle:
    data = plistlib.load(handle)
print("IconState keys:", sorted(data) if isinstance(data, dict) else type(data))

def summarize(label, items):
    print(label, "count", len(items) if isinstance(items, list) else type(items))
    if not isinstance(items, list):
        return
    for item in items[:8]:
        if isinstance(item, dict):
            print(" ", item.get("bundleIdentifier") or item.get("displayName") or sorted(item)[:6])
        else:
            print(" ", type(item))

icon = {"bundleIdentifier": bundle, "displayName": name}
changed = False
lists = data.get("iconLists") if isinstance(data, dict) else None
if isinstance(lists, list) and lists and isinstance(lists[0], list):
    summarize("page0 before", lists[0])
    lists[0] = [item for item in lists[0] if not (isinstance(item, dict) and item.get("bundleIdentifier") == bundle)]
    lists[0].insert(0, icon)
    changed = True
dock = data.get("buttonBar") if isinstance(data, dict) else None
if isinstance(dock, list):
    summarize("dock before", dock)
    dock[:] = [item for item in dock if not (isinstance(item, dict) and item.get("bundleIdentifier") == bundle)]
    dock.append(dict(icon))
    changed = True
if changed:
    with open(path, "wb") as handle:
        plistlib.dump(data, handle)
    print("wrote Trivia onto the first page and the dock")
else:
    print("could not edit iconLists or buttonBar")
PY
  cp "$plist" "$spring/DesiredIconState.plist" || true
  xcrun simctl spawn "$UDID" launchctl kickstart -k user/foreground/com.apple.SpringBoard \
    >>"$NOTES" 2>&1 || log "SpringBoard kickstart failed"
  sleep 5
}

capture_launch() {
  local mode="$1"
  set_appearance "$mode"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  sleep 1
  xcrun simctl launch "$UDID" "$BUNDLE_ID"
  log "launched for $mode"
  sleep 2
  shot "launch-${mode}.png"
  sleep $((HOLD_SECONDS - 3))
  shot "mid-${mode}.png"
  sleep 4
  shot "loaded-${mode}.png"
  sleep 2
  shot "settled-${mode}.png"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  sleep 1
}

capture_launch light
capture_launch dark

place_icon
set_appearance light
shot "home-light.png"
set_appearance dark
shot "home-dark.png"

log "trying tinted home-screen icons"
if set_appearance tinted; then
  shot "home-tinted.png"
  log "simctl accepted appearance tinted"
else
  log "simctl ui appearance tinted is not supported"
  xcrun simctl ui "$UDID" --help >>"$NOTES" 2>&1 || true
  # Best-effort SpringBoard defaults. iOS 18 does not document a simctl tint.
  xcrun simctl spawn "$UDID" defaults write com.apple.springboard SBIconAppearance -string tinted \
    >>"$NOTES" 2>&1 || log "defaults write SBIconAppearance failed"
  xcrun simctl spawn "$UDID" launchctl kickstart -k system/com.apple.SpringBoard \
    >>"$NOTES" 2>&1 || true
  sleep 3
  if xcrun simctl io "$UDID" screenshot "$OUT/home-tinted-attempt.png"; then
    log "saved home-tinted-attempt.png after an undocumented defaults write; treat as unverified"
  fi
fi

log "done"
required=(launch-light.png loaded-light.png launch-dark.png loaded-dark.png home-light.png home-dark.png)
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
