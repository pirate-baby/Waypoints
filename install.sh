#!/usr/bin/env bash
# Install the Waypoints overlay sync on an OpenPlotter / AvNav Pi.
#
# Run on the Pi as any user with sudo:
#   curl -fsSL https://raw.githubusercontent.com/pirate-baby/Waypoints/main/install.sh | bash
#
# Safe to re-run: it reuses an existing clone and replaces its own cron entry.
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
# Tags our crontab line so re-runs replace it instead of adding another.
CRON_MARKER="# waypoints-sync"

die() { echo "error: $*" >&2; exit 1; }

as_avnav() {
    if [[ "$(id -un)" == "$AVNAV_USER" ]]; then
        "$@"
    else
        sudo -u "$AVNAV_USER" -H "$@"
    fi
}

[[ -n "$AVNAV_HOME" ]] || die "user '$AVNAV_USER' not found (set AVNAV_USER)"
for cmd in git python3 crontab; do
    command -v "$cmd" >/dev/null || die "$cmd is not installed"
done
as_avnav test -d "$(dirname "$WAYPOINTS_OUT")" \
    || die "$(dirname "$WAYPOINTS_OUT") not found; is AvNav installed for '$AVNAV_USER'?"

echo "==> Repo: $INSTALL_DIR"
if as_avnav test -d "$INSTALL_DIR/.git"; then
    echo "    already cloned, sync.sh will update it"
else
    as_avnav git clone --quiet "$REPO_URL" "$INSTALL_DIR"
    echo "    cloned $REPO_URL"
fi

echo "==> Hourly cron job for $AVNAV_USER"
cron_line="0 * * * * WAYPOINTS_OUT=$WAYPOINTS_OUT $INSTALL_DIR/sync.sh >> $INSTALL_DIR/sync.log 2>&1 $CRON_MARKER"
# Also drop unmarked lines for this sync.sh (e.g. from a manual install).
{ as_avnav crontab -l 2>/dev/null | grep -vF -e "$CRON_MARKER" -e "$INSTALL_DIR/sync.sh" || true; echo "$cron_line"; } \
    | as_avnav crontab -
echo "    $cron_line"

echo "==> Building overlay"
as_avnav rm -f "$INSTALL_DIR/.last-built"
as_avnav env WAYPOINTS_OUT="$WAYPOINTS_OUT" "$INSTALL_DIR/sync.sh"

cat <<EOF

Done. One manual step left, in AvNav:
  open the chart's overlay settings, add $(basename "$WAYPOINTS_OUT"),
  and set "icon file" to $(basename "${WAYPOINTS_OUT%.gpx}")-icons.zip.

Logs: $INSTALL_DIR/sync.log
EOF
