# Bazzite + KeePassXC + Google Drive — automation scripts

These scripts assist setting up Google Drive with rclone for syncing Keepass database.
The scripts are based on manual steps described here: [bazzite-keepassxc-gdrive-sync.md](bazzite-keepassxc-gdrive-sync.md).
So you can follow the manual, or just run the scripts to get the same outcome.

Run them in order. Each script is **idempotent** — safe to re-run.

## Supported systems
Tested on Bazzite but should work on most modern Linux distros (Fedora, Ubuntu, Nobora, Mint, Pop!_OS etc)

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

### What this means for non-Bazzite users

Step 1 (`01-preflight.sh`) tries to install `rclone` with `brew install rclone`. If you don't have Homebrew, **install `rclone` first using your distro's package manager**, then re-run step 1 — it will detect the existing binary and skip the brew step:

```bash
# Fedora / RHEL family
sudo dnf install rclone fuse3
# Debian / Ubuntu family
sudo apt install rclone fuse3
# Arch family
sudo pacman -S rclone fuse3
# openSUSE
sudo zypper install rclone fuse3
```

The `99-uninstall.sh --remove-rclone` flag also assumes Homebrew. On other distros, uninstall `rclone` with the same package manager you used to install it.

| Step | Script | What it does | Interactive? |
|---|---|---|---|
| 0 | `00-install.sh` | Convenience wrapper: runs steps 1 → 4 in order, stopping on first failure. | **Yes** (delegates to step 2) |
| 1 | `01-preflight.sh` | Installs `rclone` via Homebrew if missing, detects `rclone` and `fusermount[3]` paths, enables linger. | No |
| 2 | `02-configure-rclone.sh` | Runs `rclone config` for the `gdrive` remote (skips if already configured). | **Yes** — browser auth |
| 3 | `03-install-service.sh` | Generates and installs the systemd user unit using the paths detected in step 1, enables and starts it. | No |
| 4 | `04-verify-mount.sh` | Runs the atomic-overwrite test against `~/GDrive` and verifies upload via `rclone lsf`. | No |
| — | `99-uninstall.sh` | Stops the service, unmounts, removes the unit (does **not** delete your data on Drive or uninstall rclone unless flagged). | No |

## Quick start

```bash
cd bazzite-keepassxc-gdrive-sync
chmod +x *.sh
./00-install.sh            # runs all four steps; pauses for browser auth in step 2
```

Or run the steps individually:

```bash
./01-preflight.sh
./02-configure-rclone.sh   # follow the browser prompt
./03-install-service.sh
./04-verify-mount.sh
```

After step 4 reports success, place your `.kdbx` under `~/GDrive/KeePass/` and
open it in KeePassXC. See the main guide for the recommended KeePassXC
settings.

## Configuration

The scripts read these environment variables (with defaults):

| Variable | Default | Meaning |
|---|---|---|
| `REMOTE_NAME` | `gdrive` | rclone remote name |
| `MOUNT_DIR` | `$HOME/GDrive` | local mount point |
| `CACHE_MAX_SIZE` | `5G` | `--vfs-cache-max-size` |
| `CACHE_MAX_AGE` | `720h` | `--vfs-cache-max-age` |
| `WRITE_BACK` | `5s` | `--vfs-write-back` |

Override per-run, e.g.:

```bash
MOUNT_DIR="$HOME/GDrive" CACHE_MAX_SIZE=10G ./03-install-service.sh
```

## Uninstall

```bash
./99-uninstall.sh                 # stop service, remove unit, unmount
./99-uninstall.sh --remove-rclone # also brew uninstall rclone
./99-uninstall.sh --purge-remote  # also delete the rclone remote config
```

Your `.kdbx` on Google Drive is never touched.
