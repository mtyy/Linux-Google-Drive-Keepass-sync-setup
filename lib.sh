#!/usr/bin/env bash
# Shared helpers. Source this from each step script.

set -euo pipefail

# --- defaults (overridable via env) ---
REMOTE_NAME="${REMOTE_NAME:-gdrive}"
MOUNT_DIR="${MOUNT_DIR:-$HOME/GDrive}"
CACHE_MAX_SIZE="${CACHE_MAX_SIZE:-5G}"
CACHE_MAX_AGE="${CACHE_MAX_AGE:-720h}"
WRITE_BACK="${WRITE_BACK:-5s}"
DIR_CACHE_TIME="${DIR_CACHE_TIME:-1h}"

SERVICE_NAME="rclone-${REMOTE_NAME}.service"
SERVICE_FILE="$HOME/.config/systemd/user/$SERVICE_NAME"
PATHS_CACHE="$HOME/.config/systemd/user/.${SERVICE_NAME%.service}.paths"

# --- output helpers ---
_color() { [[ -t 1 ]] && printf '\033[%sm' "$1" || true; }
log()   { printf '%s[*]%s %s\n' "$(_color '1;34')" "$(_color '0')" "$*"; }
ok()    { printf '%s[OK]%s %s\n' "$(_color '1;32')" "$(_color '0')" "$*"; }
warn()  { printf '%s[!]%s %s\n'  "$(_color '1;33')" "$(_color '0')" "$*" >&2; }
err()   { printf '%s[X]%s %s\n'  "$(_color '1;31')" "$(_color '0')" "$*" >&2; }
die()   { err "$*"; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

# Detect rclone binary path. Prefers Homebrew, then PATH.
detect_rclone() {
  local p
  for p in /home/linuxbrew/.linuxbrew/bin/rclone /usr/local/bin/rclone /usr/bin/rclone; do
    [[ -x "$p" ]] && { echo "$p"; return 0; }
  done
  if command -v rclone >/dev/null 2>&1; then
    command -v rclone
    return 0
  fi
  return 1
}

# Detect fusermount binary (prefer fusermount3).
detect_fusermount() {
  local p
  for p in /usr/bin/fusermount3 /usr/bin/fusermount; do
    [[ -x "$p" ]] && { echo "$p"; return 0; }
  done
  if command -v fusermount3 >/dev/null 2>&1; then
    command -v fusermount3; return 0
  fi
  if command -v fusermount >/dev/null 2>&1; then
    command -v fusermount; return 0
  fi
  return 1
}

save_paths() {
  mkdir -p "$(dirname "$PATHS_CACHE")"
  cat > "$PATHS_CACHE" <<EOF
RCLONE_BIN="$1"
FUSERMOUNT_BIN="$2"
EOF
}

load_paths() {
  [[ -f "$PATHS_CACHE" ]] || return 1
  # shellcheck disable=SC1090
  source "$PATHS_CACHE"
}
