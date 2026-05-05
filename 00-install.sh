#!/usr/bin/env bash
# One-shot orchestrator: runs steps 1 → 4 in order.
# Stops on the first failure. Step 2 is interactive (browser auth).
#
# Usage:
#   ./00-install.sh
#
# All env vars accepted by the individual scripts (REMOTE_NAME, MOUNT_DIR,
# CACHE_MAX_SIZE, CACHE_MAX_AGE, WRITE_BACK, DIR_CACHE_TIME) are honored.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

STEPS=(
  "01-preflight.sh"
  "02-configure-rclone.sh"
  "03-install-service.sh"
  "04-verify-mount.sh"
)

for step in "${STEPS[@]}"; do
  script="$SCRIPT_DIR/$step"
  [[ -x "$script" ]] || chmod +x "$script" 2>/dev/null || true
  log "===== Running $step ====="
  "$script"
done

ok "All steps completed successfully."
ok "Place your .kdbx under $MOUNT_DIR/KeePass/ and open it in KeePassXC."
