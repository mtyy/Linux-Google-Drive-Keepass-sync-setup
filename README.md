# Setup script for automatic syncing with Google Drive
**A poor mans Google Drive client: Creates a folder that is always synced to Google Drive.**

The scripts automate the manual steps described here: [bazzite-keepassxc-gdrive-sync.md](bazzite-keepassxc-gdrive-sync.md).
So you can follow the manual, or just run the script to get the same outcome.

Since it only uses `systemd` to start `rclone` at login, it should work on most modern Linux distros (Fedora, Ubuntu, Nobara, Mint, Pop!_OS, etc.).

> Tested for Bazzite + KeePassXC + Google Drive use case


## Quick start
Use `00-install.sh` to run all scripts in order.

```bash
cd Linux-Google-Drive-Keepass-sync-setup
chmod +x *.sh
./00-install.sh            # runs all four scripts
```
After that you can go to `~/GDrive/` (if you used the default) and open/add the KeePass database.

## Scripts

Step 1 (`01-preflight.sh`) installs `rclone` with `brew install rclone`. If you don't have Homebrew, **install `rclone` first using your distro's package manager**, then re-run step 1 — it will detect the existing binary and skip the brew step.

Each script is idempotent.



| Step | Script | What it does |
|---|---|---|
| 0 | `00-install.sh` | Convenience wrapper: runs steps 1 → 4 in order, stopping on first failure. |
| 1 | `01-preflight.sh` | Installs `rclone` via Homebrew if missing, detects `rclone` and `fusermount[3]` paths, enables linger. |
| 2 | `02-configure-rclone.sh` | Runs `rclone config` for the `gdrive` remote (skips if already configured). |
| 3 | `03-install-service.sh` | Generates and installs the systemd user unit using the paths detected in step 1, enables and starts it. |
| 4 | `04-verify-mount.sh` | Runs the atomic-overwrite test against `~/GDrive` and verifies upload via `rclone lsf`. |
| — | `99-uninstall.sh` | Stops the service, unmounts, removes the unit (does **not** delete your data on Drive or uninstall rclone unless flagged). |


## Configuration

The scripts read these environment variables:

| Variable | Default | Meaning |
|---|---|---|
| `REMOTE_NAME` | `gdrive` | rclone remote name |
| `MOUNT_DIR` | `$HOME/GDrive` | local mount point |
| `CACHE_MAX_SIZE` | `5G` | `--vfs-cache-max-size` |
| `CACHE_MAX_AGE` | `720h` | `--vfs-cache-max-age` |
| `WRITE_BACK` | `5s` | `--vfs-write-back` |
| `DIR_CACHE_TIME` | `1h` | `--dir-cache-time` |


## Uninstall

```bash
./99-uninstall.sh                 # stop service, remove unit, unmount
./99-uninstall.sh --remove-rclone # also brew uninstall rclone
./99-uninstall.sh --purge-remote  # also delete the rclone remote config
```

## Warning on Google Drive
Rclone is a pragmatic choice for syncing with Google Drive. However it has no conflict handling — if the same file is saved from two places before syncing, one version silently overwrites the other. For a more robust KeePass setup on Linux, consider other cloud hosts which do have a Linux client to handle conflicts, such as Syncthing or Dropbox.

## Disclaimer

This software is provided "as is", without warranty of any kind, express or implied. Use at your own risk.
