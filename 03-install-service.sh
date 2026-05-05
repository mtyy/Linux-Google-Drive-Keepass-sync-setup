#!/usr/bin/env bash
# Step 3: generate and install the systemd user unit, then enable + start it.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

load_paths || die "run ./01-preflight.sh first"
require_cmd systemctl

# Verify remote exists before installing a service that depends on it.
"$RCLONE_BIN" listremotes | grep -qx "${REMOTE_NAME}:" \
  || die "rclone remote '$REMOTE_NAME' not found; run ./02-configure-rclone.sh first"

mkdir -p "$(dirname "$SERVICE_FILE")"

log "Writing $SERVICE_FILE"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Rclone mount of ${REMOTE_NAME}: at ${MOUNT_DIR}
After=network-online.target
Wants=network-online.target

[Service]
Type=notify# First mount may take >90s while rclone warms the dir cache; bump the
# default systemd start timeout so a slow first start isn't marked failed.
TimeoutStartSec=300ExecStartPre=/bin/mkdir -p ${MOUNT_DIR}
ExecStart=${RCLONE_BIN} mount ${REMOTE_NAME}: ${MOUNT_DIR} \\
  --vfs-cache-mode full \\
  --vfs-cache-max-age ${CACHE_MAX_AGE} \\
  --vfs-cache-max-size ${CACHE_MAX_SIZE} \\
  --vfs-write-back ${WRITE_BACK} \\
  --dir-cache-time ${DIR_CACHE_TIME} \\
  --umask 077
ExecStop=${FUSERMOUNT_BIN} -u ${MOUNT_DIR}
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF
chmod 0644 "$SERVICE_FILE"
ok "Unit written"

log "Reloading systemd user daemon..."
systemctl --user daemon-reload

# If the unit is already running, restart to pick up changes.
if systemctl --user is-active --quiet "$SERVICE_NAME"; then
  log "Service is running; restarting to apply changes..."
  systemctl --user restart "$SERVICE_NAME"
else
  log "Enabling and starting $SERVICE_NAME..."
  systemctl --user enable --now "$SERVICE_NAME"
fi

# Wait up to 60s for the mount to come up (first start can be slow while
# rclone warms its dir cache).
MOUNT_DIR_REAL="$(readlink -f "$MOUNT_DIR" 2>/dev/null || echo "$MOUNT_DIR")"
deadline=$((SECONDS + 60))
while (( SECONDS < deadline )); do
  if mountpoint -q "$MOUNT_DIR_REAL" 2>/dev/null \
     || mount | grep -qE " on (${MOUNT_DIR}|${MOUNT_DIR_REAL}) "; then
    ok "Mount is live at $MOUNT_DIR"
    ok "Service installed. Next: ./04-verify-mount.sh"
    exit 0
  fi
  sleep 1
done

if ! systemctl --user is-active --quiet "$SERVICE_NAME"; then
  err "Service failed to start. Recent logs:"
  journalctl --user -u "$SERVICE_NAME" -n 30 --no-pager || true
  exit 1
fi

warn "Service is active but $MOUNT_DIR did not appear mounted within 60s; check logs"
exit 1
