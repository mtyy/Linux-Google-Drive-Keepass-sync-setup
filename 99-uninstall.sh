#!/usr/bin/env bash
# Stop service, unmount, remove unit. Optionally remove rclone and remote config.
#
# Usage:
#   ./99-uninstall.sh                  # service + unit only
#   ./99-uninstall.sh --purge-remote   # also delete rclone remote
#   ./99-uninstall.sh --remove-rclone  # also brew uninstall rclone
#   ./99-uninstall.sh --all            # both of the above

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

PURGE_REMOTE=0
REMOVE_RCLONE=0
for arg in "$@"; do
  case "$arg" in
    --purge-remote)  PURGE_REMOTE=1 ;;
    --remove-rclone) REMOVE_RCLONE=1 ;;
    --all)           PURGE_REMOTE=1; REMOVE_RCLONE=1 ;;
    -h|--help)
      sed -n '2,9p' "$0"; exit 0 ;;
    *) die "unknown flag: $arg" ;;
  esac
done

load_paths || warn "no cached paths; will use \$PATH lookups"
RCLONE_BIN="${RCLONE_BIN:-$(command -v rclone || true)}"
FUSERMOUNT_BIN="${FUSERMOUNT_BIN:-$(detect_fusermount || true)}"

if systemctl --user list-unit-files | grep -q "^${SERVICE_NAME}"; then
  log "Stopping and disabling $SERVICE_NAME..."
  systemctl --user disable --now "$SERVICE_NAME" || true
else
  log "Service $SERVICE_NAME not installed; skipping"
fi

if mount | grep -q " on $MOUNT_DIR "; then
  log "Unmounting $MOUNT_DIR..."
  [[ -n "${FUSERMOUNT_BIN:-}" ]] && "$FUSERMOUNT_BIN" -u "$MOUNT_DIR" || true
fi

if [[ -f "$SERVICE_FILE" ]]; then
  log "Removing $SERVICE_FILE"
  rm -f "$SERVICE_FILE"
  systemctl --user daemon-reload
fi

[[ -f "$PATHS_CACHE" ]] && rm -f "$PATHS_CACHE"

# Only rmdir the mount point if it's empty (don't nuke user data).
if [[ -d "$MOUNT_DIR" ]] && [[ -z "$(ls -A "$MOUNT_DIR" 2>/dev/null)" ]]; then
  rmdir "$MOUNT_DIR" || true
fi

if (( PURGE_REMOTE == 1 )) && [[ -n "${RCLONE_BIN:-}" ]]; then
  if "$RCLONE_BIN" listremotes | grep -qx "${REMOTE_NAME}:"; then
    log "Deleting rclone remote '$REMOTE_NAME'..."
    "$RCLONE_BIN" config delete "$REMOTE_NAME" || true
  fi
fi

if (( REMOVE_RCLONE == 1 )); then
  if command -v brew >/dev/null 2>&1 && brew list rclone >/dev/null 2>&1; then
    log "Uninstalling rclone via Homebrew..."
    brew uninstall rclone || true
  else
    warn "rclone not installed via Homebrew; skipping uninstall"
  fi
fi

ok "Uninstall complete. Your .kdbx on Google Drive is untouched."
