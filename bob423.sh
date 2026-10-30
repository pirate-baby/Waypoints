#!/usr/bin/env bash
# Download the latest Bob423 ICW long tracks into the AvNav overlays directory.
#
# Bob423 (https://bobicw.blogspot.com/p/bob423-long-tracks.html) publishes
# deep-water GPX tracks for the ICW. Each update gets a new dated filename,
# but the links on his "Long Tracks" page always point at the current file.
# This script reads that page, finds each section's current link, and saves
# it under a fixed name so the AvNav overlay config never has to change.
#
# Intended to run daily from cron as the user AvNav runs as (pi), e.g.:
#   15 5 * * * /path/to/bob423.sh >> $HOME/bob423.log 2>&1
#
# Only the page is fetched on most runs; a track is downloaded only when its
# link changes, or weekly for undated files whose URL never changes. If the
# boat is offline or a download fails, existing files are left in place.
#
# The tracks are for personal use only; don't commit or redistribute them.
#
# Override defaults with env vars:
#   BOB423_DIR    output directory (default /home/pi/avnav/data/overlays)
#   BOB423_STATE  state directory  (default ~/.cache/bob423)
set -uo pipefail

PAGE="https://bobicw.blogspot.com/p/bob423-long-tracks.html"
OUT_DIR="${BOB423_DIR:-/home/pi/avnav/data/overlays}"
STATE_DIR="${BOB423_STATE:-${XDG_CACHE_HOME:-$HOME/.cache}/bob423}"
# Re-download files whose URL hasn't changed after this many days
# (catches updates to undated files like the side tracks).
MAX_AGE_DAYS=7

# fixed output name | filename prefix on bob423.com (URL-encoded)
SECTIONS=(
    "bob423-norfolk-southport|B423%20Norfolk%20to%20Southport"
    "bob423-southport-savannah|B423%20Southport%20to%20Savannah"
    "bob423-savannah-titusville|B423%20Savannah%20to%20Titusville"
    "bob423-titusville-miami|B423%20Titusville%20to%20Miami"
    "bob423-side-tracks|Bob423%20All%20Side%20Tracks"
)

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

mkdir -p "$OUT_DIR" "$STATE_DIR"

if ! html="$(curl -fsSL --max-time 60 "$PAGE")"; then
    log "page fetch failed (offline?), keeping existing tracks"
    exit 0
fi

links="$(echo "$html" \
    | grep -oE 'https://bob423\.com/long/[^"<> ]+\.gpx' \
    | sed 's/ /%20/g' | sort -u || true)"

if [[ -z "$links" ]]; then
    log "no track links found on page (layout changed?), keeping existing tracks"
    exit 0
fi

for entry in "${SECTIONS[@]}"; do
    name="${entry%%|*}"
    prefix="${entry#*|}"
    out="$OUT_DIR/$name.gpx"
    stamp="$STATE_DIR/$name.url"

    url="$(echo "$links" | grep -F "/long/${prefix}" | head -1 || true)"
    if [[ -z "$url" ]]; then
        log "$name: no link found, keeping existing file"
        continue
    fi

    # Skip if the link hasn't changed and the file is recent.
    if [[ -f "$out" && -f "$stamp" && "$(cat "$stamp")" == "$url" ]] \
        && [[ -z "$(find "$out" -mtime +"$MAX_AGE_DAYS" 2>/dev/null)" ]]; then
        continue
    fi

    tmp="$(mktemp)"
    if curl -fsSL --max-time 120 -o "$tmp" "$url" && grep -q "<gpx" "$tmp"; then
        mv "$tmp" "$out"
        chmod 644 "$out"
        echo "$url" > "$stamp"
        log "$name: updated from $url"
    else
        rm -f "$tmp"
        log "$name: download failed, keeping existing file"
    fi
done
