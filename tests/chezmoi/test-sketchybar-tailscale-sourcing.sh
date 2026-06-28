#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RC="$ROOT/dot_config/sketchybar/executable_sketchybarrc"
ITEM="$ROOT/dot_config/sketchybar/items/tailscale.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
[ -f "$ITEM" ] || fail "items/tailscale.sh missing"
[ -r "$ITEM" ] || fail "items/tailscale.sh not readable"

# Inspect the rc's right-items block in source order.
order="$(awk '
  /# right items/ {right=1; next}
  /^# finalise/ {right=0}
  right && /^[[:space:]]*source "\$ITEM_DIR\// {
    sub(/.*source "\$ITEM_DIR\//, ""); sub(/\.sh".*/, ""); print
  }
' "$RC")"

expect=$'calendar\nbattery\ntailscale\nspotify'
[ "$order" = "$expect" ] || fail "right source order wrong: got <$order> want <$expect>"

grep -q 'sketchybar --add item tailscale right' "$ITEM" || fail "item not added on right"
grep -q 'update_freq=30' "$ITEM" || fail "missing update_freq=30"
grep -q 'system_woke' "$ITEM" || fail "missing system_woke subscription"
grep -q -- "--set tailscale" "$ITEM" || fail "missing --set tailscale"

echo "SOURCING OK"
