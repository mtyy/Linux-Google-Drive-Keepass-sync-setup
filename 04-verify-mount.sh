#!/usr/bin/env bash
# Step 4: verify the mount handles atomic overwrite + rename correctly,
# and that the result actually lands on Google Drive.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

load_paths || die "run ./01-preflight.sh first"

systemctl --user is-active --quiet "$SERVICE_NAME" \
  || die "$SERVICE_NAME is not active; run ./03-install-service.sh"

if ! mount | grep -q " on $MOUNT_DIR "; then
  die "$MOUNT_DIR is not mounted"
fi

TEST_DIR="$MOUNT_DIR/.kpxc-sync-selftest"
TEST_FILE="$TEST_DIR/sync-test.txt"
TEST_TMP="$TEST_DIR/sync-test.tmp"

cleanup() {
  rm -f "$TEST_FILE" "$TEST_TMP" 2>/dev/null || true
  rmdir "$TEST_DIR" 2>/dev/null || true
  # Best-effort cleanup on the remote too.
  "$RCLONE_BIN" delete --quiet "${REMOTE_NAME}:.kpxc-sync-selftest" 2>/dev/null || true
  "$RCLONE_BIN" rmdir --quiet "${REMOTE_NAME}:.kpxc-sync-selftest" 2>/dev/null || true
}
trap cleanup EXIT

log "Creating test directory in mount..."
mkdir -p "$TEST_DIR"

log "Writing v1, then atomic-overwrite via rename to v2..."
echo "v1" > "$TEST_FILE"
echo "v2" > "$TEST_TMP"
mv "$TEST_TMP" "$TEST_FILE"

actual="$(cat "$TEST_FILE")"
[[ "$actual" == "v2" ]] || die "local read after rename returned '$actual', expected 'v2'"
ok "Local atomic-overwrite works"

log "Waiting up to 30s for upload to Google Drive..."
deadline=$((SECONDS + 30))
remote_path=".kpxc-sync-selftest/sync-test.txt"
found=0
while (( SECONDS < deadline )); do
  if "$RCLONE_BIN" lsf "${REMOTE_NAME}:.kpxc-sync-selftest" 2>/dev/null \
       | grep -qx "sync-test.txt"; then
    found=1
    break
  fi
  sleep 2
done

(( found == 1 )) || die "file not visible on remote after 30s — sync may be broken"

log "Verifying remote file content..."
remote_content="$("$RCLONE_BIN" cat "${REMOTE_NAME}:${remote_path}")"
[[ "$remote_content" == "v2" ]] \
  || die "remote content is '$remote_content', expected 'v2'"

ok "Remote shows correct post-rename content"
ok "Mount is safe for KeePassXC. You can now place your .kdbx under $MOUNT_DIR/KeePass/"
