#!/usr/bin/env bash
# Step 1: install rclone (if missing), detect required binary paths, enable linger.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

log "Detecting rclone..."
if ! RCLONE_BIN="$(detect_rclone)"; then
  log "rclone not found; installing via Homebrew..."
  require_cmd brew
  brew install rclone
  RCLONE_BIN="$(detect_rclone)" || die "rclone still not found after install"
fi
ok "rclone: $RCLONE_BIN ($("$RCLONE_BIN" version | head -n1))"

log "Detecting fusermount..."
FUSERMOUNT_BIN="$(detect_fusermount)" \
  || die "neither fusermount3 nor fusermount found in /usr/bin — FUSE missing from base image"
ok "fusermount: $FUSERMOUNT_BIN"

save_paths "$RCLONE_BIN" "$FUSERMOUNT_BIN"
ok "Saved paths to $PATHS_CACHE"

log "Enabling user service linger (so the mount survives logout/reboot)..."
if loginctl show-user "$USER" 2>/dev/null | grep -q '^Linger=yes'; then
  ok "Linger already enabled"
else
  loginctl enable-linger "$USER"
  ok "Linger enabled for $USER"
fi

log "Ensuring mount directory exists: $MOUNT_DIR"
mkdir -p "$MOUNT_DIR"

ok "Preflight complete. Next: ./02-configure-rclone.sh"
