#!/usr/bin/env bash
# Pull the latest waypoints from GitHub and regenerate the AvNav overlay.
#
# Intended to run hourly as the user AvNav runs as (pi), from a clone of this
# repo on the OpenPlotter box. Only rebuilds when the remote has changed or the
# output file is missing, so it's cheap to run often.
#
# Override defaults with env vars:
#   WAYPOINTS_OUT    output gpx (default /home/pi/avnav/data/overlays/waypoints.gpx)
#   WAYPOINTS_BRANCH branch to track (default main)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${WAYPOINTS_OUT:-/home/pi/avnav/data/overlays/waypoints.gpx}"
BRANCH="${WAYPOINTS_BRANCH:-main}"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

cd "$REPO_DIR"

# The boat isn't always online; skip quietly rather than failing.
if ! git fetch --quiet origin "$BRANCH" 2>/dev/null; then
    log "fetch failed (offline?), keeping existing $OUT"
    exit 0
fi

ICONS="${OUT%.gpx}-icons.zip"
# Records the last revision that converted successfully, so a failed build
# (e.g. an icon download while offline) is retried on the next run.
STAMP="$REPO_DIR/.last-built"

remote_rev="$(git rev-parse "origin/$BRANCH")"
built_rev="$(cat "$STAMP" 2>/dev/null || true)"

if [[ "$built_rev" == "$remote_rev" && -f "$OUT" && -f "$ICONS" ]]; then
    exit 0
fi

# This clone is deploy-only, so discard any local edits.
git reset --quiet --hard "origin/$BRANCH"
log "building ${remote_rev:0:7}"

python3 "$REPO_DIR/csv_to_gpx.py" "$REPO_DIR/waypoints.csv" -o "$OUT" --icons "$ICONS"
echo "$remote_rev" > "$STAMP"
