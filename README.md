# Setup script for automatic syncing with Google Drive using rclone
> Tested for Bazzite + KeePassXC + Google Drive use case, but of course also works if you just want to sync your Google Drive this way.

The scripts automate the manual steps described here: [bazzite-keepassxc-gdrive-sync.md](bazzite-keepassxc-gdrive-sync.md).
So you can follow the manual, or just run the script to get the same outcome.

Each script is idempotent — safe to re-run.

## Quick start
Use `00-install.sh` to run all scripts in order.

```bash
cd Linux-Google-Drive-Keepass-sync-setup
chmod +x *.sh
./00-install.sh            # runs all four scripts
```
After that you can go to `~/GDrive/` (if you used the default) and open/add the KeePass database.

## Supported systems
Since it only uses systemd to start rclone at login, it should work on most modern Linux distros (Fedora, Ubuntu, Nobara, Mint, Pop!_OS, etc.).


## Scripts

Step 1 (`01-preflight.sh`) tries to install `rclone` with `brew install rclone`. If you don't have Homebrew, **install `rclone` first using your distro's package manager**, then re-run step 1 — it will detect the existing binary and skip the brew step.



| Step | Script | What it does | Interactive? |
|---|---|---|---|
| 0 | `00-install.sh` | Convenience wrapper: runs steps 1 → 4 in order, stopping on first failure. | **Yes** (delegates to step 2) |
| 1 | `01-preflight.sh` | Installs `rclone` via Homebrew if missing, detects `rclone` and `fusermount[3]` paths, enables linger. | No |
| 2 | `02-configure-rclone.sh` | Runs `rclone config` for the `gdrive` remote (skips if already configured). | **Yes** — browser auth |
| 3 | `03-install-service.sh` | Generates and installs the systemd user unit using the paths detected in step 1, enables and starts it. | No |
| 4 | `04-verify-mount.sh` | Runs the atomic-overwrite test against `~/GDrive` and verifies upload via `rclone lsf`. | No |
| — | `99-uninstall.sh` | Stops the service, unmounts, removes the unit (does **not** delete your data on Drive or uninstall rclone unless flagged). | No |



## Configuration

The scripts read these environment variables (with defaults):

| Variable | Default | Meaning |
|---|---|---|
| `REMOTE_NAME` | `gdrive` | rclone remote name |
| `MOUNT_DIR` | `$HOME/GDrive` | local mount point |
| `CACHE_MAX_SIZE` | `5G` | `--vfs-cache-max-size` |
| `CACHE_MAX_AGE` | `720h` | `--vfs-cache-max-age` |
| `WRITE_BACK` | `5s` | `--vfs-write-back` |
| `DIR_CACHE_TIME` | `1h` | `--dir-cache-time` |


## Dependencies & assumptions

The scripts assume the following are present on the system:

| Dependency | Used by | Notes |
|---|---|---|
| `bash` 4+ | all scripts | shebang is `/usr/bin/env bash` |
| `systemd` with user-services | step 3, 4, 99 | `systemctl --user`, `journalctl --user` |
| `loginctl` | step 1 | to enable user linger |
| FUSE in kernel + `fusermount3` (or `fusermount`) in `/usr/bin` | step 3 | required for `rclone mount` |
| `mount` / `mountpoint` | step 3, 4 | coreutils / util-linux |
| **`rclone`** | step 1, 2, 3, 4 | step 1 will auto-install it **only via Homebrew** (see below) |
| **Homebrew (`brew`)** | step 1, 99 | only required if `rclone` is not already installed; preinstalled on Bazzite/uBlue, **not** on most other distros |
| A web browser (for OAuth) | step 2 | `rclone config` opens a browser for Google sign-in |

## Uninstall

```bash
./99-uninstall.sh                 # stop service, remove unit, unmount
./99-uninstall.sh --remove-rclone # also brew uninstall rclone
./99-uninstall.sh --purge-remote  # also delete the rclone remote config
```

## Note on rclone use
Rclone itself has no conflict handling — if the same file is saved from two places before syncing, one version silently overwrites the other. For a more robust KeePass setup on Linux, consider other hosting options such as Syncthing or Dropbox which have a native client to handle conflicts.

## Disclaimer

This software is provided "as is", without warranty of any kind, express or implied. Use at your own risk.
