#!/usr/bin/env bash
# Install the Waypoints overlay sync on an OpenPlotter / AvNav Pi.
#
# Run on the Pi as any user with sudo:
#   curl -fsSL https://raw.githubusercontent.com/pirate-baby/Waypoints/main/install.sh | bash
#
# Add --bob to also install the daily Bob423 ICW track download (bob423.sh):
#   curl -fsSL https://raw.githubusercontent.com/pirate-baby/Waypoints/main/install.sh | bash -s -- --bob
#
# Safe to re-run: it reuses an existing clone and replaces its own cron entries.
# Re-running without --bob removes the Bob423 cron entry if one was installed.
#
# Override defaults with env vars:
#   AVNAV_USER   user AvNav runs as (default pi)
#   INSTALL_DIR  where to clone the repo (default /home/$AVNAV_USER/Waypoints)
#   WAYPOINTS_OUT  output gpx (default /home/$AVNAV_USER/avnav/data/overlays/waypoints.gpx)
set -euo pipefail

REPO_URL="https://github.com/pirate-baby/Waypoints.git"
AVNAV_USER="${AVNAV_USER:-pi}"
AVNAV_HOME="$(getent passwd "$AVNAV_USER" | cut -d: -f6 || true)"
INSTALL_DIR="${INSTALL_DIR:-$AVNAV_HOME/Waypoints}"
WAYPOINTS_OUT="${WAYPOINTS_OUT:-$AVNAV_HOME/avnav/data/overlays/waypoints.gpx}"
OVERLAY_DIR="$(dirname "$WAYPOINTS_OUT")"
# Tags our crontab lines so re-runs replace them instead of adding more.
CRON_MARKER="# waypoints-sync"
BOB423_MARKER="# waypoints-bob423"

die() { echo "error: $*" >&2; exit 1; }

WITH_BOB=0
for arg in "$@"; do
    case "$arg" in
        --bob) WITH_BOB=1 ;;
        -h|--help)
            sed -n '2,16p' "${BASH_SOURCE[0]:-/dev/null}" 2>/dev/null | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) die "unknown option: $arg (supported: --bob)" ;;
    esac
done

as_avnav() {
    if [[ "$(id -un)" == "$AVNAV_USER" ]]; then
        "$@"
    else
        sudo -u "$AVNAV_USER" -H "$@"
    fi
}

[[ -n "$AVNAV_HOME" ]] || die "user '$AVNAV_USER' not found (set AVNAV_USER)"
required=(git python3 crontab)
(( WITH_BOB )) && required+=(curl)
for cmd in "${required[@]}"; do
    command -v "$cmd" >/dev/null || die "$cmd is not installed"
done
as_avnav test -d "$OVERLAY_DIR" \
    || die "$OVERLAY_DIR not found; is AvNav installed for '$AVNAV_USER'?"

echo "==> Repo: $INSTALL_DIR"
if as_avnav test -d "$INSTALL_DIR/.git"; then
    echo "    already cloned, sync.sh will update it"
else
    as_avnav git clone --quiet "$REPO_URL" "$INSTALL_DIR"
    echo "    cloned $REPO_URL"
fi

echo "==> Cron jobs for $AVNAV_USER"
cron_line="0 * * * * WAYPOINTS_OUT=$WAYPOINTS_OUT $INSTALL_DIR/sync.sh >> $INSTALL_DIR/sync.log 2>&1 $CRON_MARKER"
bob423_line="15 5 * * * BOB423_DIR=$OVERLAY_DIR $INSTALL_DIR/bob423.sh >> $INSTALL_DIR/bob423.log 2>&1 $BOB423_MARKER"
# Also drop unmarked lines for these scripts (e.g. from a manual install).
{ as_avnav crontab -l 2>/dev/null \
    | grep -vF -e "$CRON_MARKER" -e "$BOB423_MARKER" \
               -e "$INSTALL_DIR/sync.sh" -e "$INSTALL_DIR/bob423.sh" || true
  echo "$cron_line"
  if (( WITH_BOB )); then echo "$bob423_line"; fi; } \
    | as_avnav crontab -
echo "    $cron_line"
if (( WITH_BOB )); then
    echo "    $bob423_line"
fi

echo "==> Building overlay"
as_avnav rm -f "$INSTALL_DIR/.last-built"
as_avnav env WAYPOINTS_OUT="$WAYPOINTS_OUT" "$INSTALL_DIR/sync.sh"

if (( WITH_BOB )); then
    echo "==> Downloading Bob423 tracks"
    as_avnav chmod +x "$INSTALL_DIR/bob423.sh"
    as_avnav env BOB423_DIR="$OVERLAY_DIR" "$INSTALL_DIR/bob423.sh" \
        | as_avnav tee -a "$INSTALL_DIR/bob423.log" || true
fi

cat <<EOF

Done. One manual step left, in AvNav:
  open the chart's overlay settings, add $(basename "$WAYPOINTS_OUT"),
  and set "icon file" to $(basename "${WAYPOINTS_OUT%.gpx}")-icons.zip.
EOF

if (( WITH_BOB )); then
    cat <<EOF
  Add whichever bob423-*.gpx tracks you want as overlays the same way.

Logs: $INSTALL_DIR/sync.log, $INSTALL_DIR/bob423.log
EOF
else
    echo
    echo "Logs: $INSTALL_DIR/sync.log"
fi
