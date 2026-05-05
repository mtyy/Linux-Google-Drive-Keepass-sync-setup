#!/usr/bin/env bash
# Step 2: configure the Google Drive remote. Interactive (browser auth required).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

load_paths || die "run ./01-preflight.sh first"

log "Checking for existing remote '$REMOTE_NAME'..."
if "$RCLONE_BIN" listremotes | grep -qx "${REMOTE_NAME}:"; then
  ok "Remote '$REMOTE_NAME' already exists. Verifying access..."
  if "$RCLONE_BIN" lsd "${REMOTE_NAME}:" >/dev/null 2>&1; then
    ok "Remote works. Skipping reconfiguration."
    exit 0
  fi
  warn "Remote exists but access failed. Try: '$RCLONE_BIN config reconnect ${REMOTE_NAME}:'"
  exit 1
fi

# $REMOTE_NAME default is gdrive
cat <<EOF

================================================================
About to launch interactive 'rclone config' for remote: $REMOTE_NAME

Answer the prompts as follows:
  Remote name:         $REMOTE_NAME
  Storage type:        drive
  client_id / secret:  (leave blank)
  scope:               1 (full)
  service_account:     (leave blank)
  Edit advanced:       n
  Use auto config:     y   <-- a browser will open for Google login
  Shared Drive:        n   (only asked if you have one)
  Confirm:             y, then q
================================================================

EOF
read -r -p "Press Enter to launch rclone config (Ctrl-C to abort)..."

"$RCLONE_BIN" config

log "Verifying new remote..."
"$RCLONE_BIN" lsd "${REMOTE_NAME}:" >/dev/null \
  || die "remote '$REMOTE_NAME' configured but lsd failed; re-run this script"

ok "Remote '$REMOTE_NAME' configured. Next: ./03-install-service.sh"
