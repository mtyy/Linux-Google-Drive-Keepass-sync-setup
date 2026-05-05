# Syncing a KeePassXC Database with Google Drive on Bazzite (KDE)

This guide sets up reliable two-way sync of a KeePassXC `.kdbx` database between
your Bazzite machine and Google Drive using `rclone mount` with a full VFS
cache. The mount behaves like a local folder, so KeePassXC's atomic save
(write-temp → fsync → rename) and lock files work correctly, and changes are
uploaded to Drive automatically a few seconds after each save.

Assumptions:

- Bazzite (Fedora Atomic / immutable) with KDE Plasma.
- KeePassXC is already installed (e.g. via `rpm-ostree` layering so the browser
  extension can talk to it). This guide does **not** reinstall it.
- You have a Google account and an existing or new `.kdbx` database.

---

## Phase 1 — Install rclone

Bazzite ships Homebrew preinstalled. Use it to avoid layering more packages.

```bash
brew install rclone
which rclone     # expect: /home/linuxbrew/.linuxbrew/bin/rclone
rclone version
```

If `rclone` is already on `PATH` from the base image, you can skip the install
and just note the path returned by `which rclone` — you'll need it in the
systemd unit later.

Also check the FUSE unmount binary path now — you'll need it in the systemd
unit:

```bash
which fusermount3      # expected on recent Bazzite
which fusermount       # fallback on older images
```

Use whichever one returns a path in the `ExecStop=` line later.

---

## Phase 2 — Configure the Google Drive remote

```bash
rclone config
```

Answer the prompts as follows:

1. `n` — new remote
2. Name: `gdrive`
3. Storage type: `drive` (Google Drive)
4. `client_id` / `client_secret`: leave blank (press Enter).
   Optional: create your own OAuth client in Google Cloud Console for higher
   API rate limits — recommended if you sync frequently or from many devices.
5. Scope:
   - `1` (full `drive` access) — simplest; choose this if your `.kdbx` is
     already on Drive from another device.
   - `3` (`drive.file`) — safer; rclone only sees files it created. If you
     pick this, you must upload the initial `.kdbx` via rclone (see Phase 4)
     because rclone won't see a file uploaded through the web UI.
6. `service_account_file`: leave blank.
7. `Edit advanced config?` — `n`.
8. `Use auto config?` — `y`. A browser opens; sign in and approve.
9. `Configure this as a Shared Drive?` — `n` for a personal account.
   (This prompt only appears if your account has Shared Drives.)
10. Confirm with `y`, then `q` to quit.

Verify:

```bash
rclone lsd gdrive:
```

You should see your top-level Drive folders (or be empty if you chose
`drive.file` scope and haven't uploaded anything yet).

---

## Phase 3 — Create the mount point and systemd user service

### 3.1 Create the local mount directory

```bash
mkdir -p ~/GDrive
```

### 3.2 Create the systemd user unit

```bash
mkdir -p ~/.config/systemd/user
nano ~/.config/systemd/user/rclone-gdrive.service
```

Paste:

```ini
[Unit]
Description=Rclone Google Drive Mount
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/home/linuxbrew/.linuxbrew/bin/rclone mount gdrive: %h/GDrive \
  --vfs-cache-mode full \
  --vfs-cache-max-age 720h \
  --vfs-cache-max-size 5G \
  --vfs-write-back 5s \
  --dir-cache-time 1h \
  --umask 077
ExecStop=/usr/bin/fusermount3 -u %h/GDrive
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
```

Why these flags:

| Flag | Purpose |
|---|---|
| `--vfs-cache-mode full` | **Required.** Makes the mount behave like a real local filesystem. KeePassXC's temp-file-then-rename save pattern only works with this mode. Without it, saves will fail or corrupt the DB. |
| `--vfs-cache-max-age 720h` | Keep cached files for 30 days. Ensures your `.kdbx` is available offline and avoids needless re-downloads. The cache is small (KB–MB for a typical DB). |
| `--vfs-cache-max-size 5G` | Safety valve. If you ever browse `~/GDrive` and accidentally open a large file (video, ISO), the cache won't eat your SSD — rclone evicts the least-recently-used files when this size is exceeded. Adjust to taste. |
| `--vfs-write-back 5s` | Upload to Drive 5 seconds after the file is closed locally. |
| `--dir-cache-time 1h` | Cache directory listings for 1h to reduce API calls. |
| `--umask 077` | Make the mount and cached files private to your user. |
| `Type=notify` | Rclone signals systemd when the mount is actually ready, avoiding races. |

If `which rclone` or `which fusermount3` returned different paths, edit
`ExecStart` / `ExecStop` accordingly.

### 3.3 Enable and start

```bash
systemctl --user daemon-reload
systemctl --user enable --now rclone-gdrive.service
systemctl --user status rclone-gdrive.service
```

Expect `active (running)`.

### 3.4 Make user services start at boot (without login)

By default, systemd user services only run while you're logged in. To keep the
mount alive across reboots even before you log in:

```bash
loginctl enable-linger "$USER"
```

---

## Phase 4 — Verify the mount is safe for KeePassXC

Confirm the mount is up:

```bash
mount | grep GDrive      # should show a fuse.rclone entry
ls ~/GDrive              # should list your Drive contents
```

Run the **atomic-overwrite test** — this simulates exactly what KeePassXC does
on save:

```bash
cd ~/GDrive
echo "v1" > sync-test.txt
echo "v2" > sync-test.tmp
mv sync-test.tmp sync-test.txt   # overwrite via rename — the critical op
cat sync-test.txt                # must print: v2
```

No `Input/output error` or `Operation not supported` means the mount handles
atomic saves correctly. Wait ~10 seconds, then verify the upload reached
Drive — query the remote directly instead of trusting the web UI cache:

```bash
rclone lsf gdrive: | grep sync-test
```

You should see `sync-test.txt` and **not** `sync-test.tmp`. That confirms the
rename was applied server-side, not just locally. Then clean up:

```bash
rm ~/GDrive/sync-test.txt
```

---

## Phase 5 — Place your KeePassXC database in the mount

### If your `.kdbx` is already on Google Drive

Just open it from `~/GDrive/path/to/Passwords.kdbx` in KeePassXC.

### If your `.kdbx` is currently local only

Pick one of:

**Option A — copy via the mount (works with any scope):**

```bash
mkdir -p ~/GDrive/KeePass
cp ~/Passwords.kdbx ~/GDrive/KeePass/
```

**Option B — upload via rclone (required if you chose `drive.file` scope):**

```bash
rclone copy ~/Passwords.kdbx gdrive:KeePass/
```

Then open `~/GDrive/KeePass/Passwords.kdbx` in KeePassXC.

> **Important:** always open the database from `~/GDrive/...`, never from the
> original local copy. Otherwise edits won't sync.

---

## Phase 6 — KeePassXC settings

Open KeePassXC → **Settings**.

**Settings → General → File Management:**

- ✅ **Safely save database files** — leave **checked**. The full VFS cache
  supports atomic saves correctly. Only uncheck this if you ever see actual
  save failures.
- ✅ **Automatically reload the database when modified externally** — pick this
  up changes made on other devices (e.g. KeePass2Android on your phone).
- ✅ **Backup database file before saving** (optional but recommended).

**Settings → Security:**

- ✅ **Lock database after inactivity** (e.g. 5–10 minutes). Good hygiene
  since the DB file is now effectively always-online.

---

## How a save flows end-to-end

1. You edit an entry in KeePassXC and press Save.
2. KeePassXC writes to `~/GDrive/KeePass/Passwords.kdbx.tmp` (a real local file
   inside the rclone cache), `fsync`s it, then `rename`s it over the original.
   All operations are local and atomic.
3. ~5 seconds after the file is closed, rclone uploads the new `.kdbx` to
   Google Drive in the background.
4. On another device that also opens this file, the new mtime triggers
   KeePassXC's "auto-reload" and the updated entries appear.

---

## Troubleshooting

**Service won't start / mount empty:**

```bash
systemctl --user status rclone-gdrive.service
journalctl --user -u rclone-gdrive.service -n 100 --no-pager
```

Common causes: wrong `rclone` path in `ExecStart`, `~/GDrive` not empty before
mount (must be empty), token expired (re-run `rclone config reconnect gdrive:`).

**`fusermount3: command not found`:**
Install with `brew install fuse` is **not** the answer on Bazzite — FUSE is
provided by the base OS. Check `/usr/bin/fusermount3` exists; if only
`/usr/bin/fusermount` exists on your image, use that path instead.

**Saves fail with "could not save database":**
Confirm the unit really has `--vfs-cache-mode full` (not `writes` or absent):

```bash
systemctl --user cat rclone-gdrive.service | grep vfs-cache-mode
```

**Conflicts from editing on multiple devices simultaneously:**
A mount-based setup is last-writer-wins at the *file* level. Two strategies
to mitigate:

1. **KeePassXC entry-level merge** — instead of `Database → Open`, use
   `Database → Tools → Synchronize Database with File…` and point it at the
   `~/GDrive/...kdbx`. KeePassXC reads each entry's internal timestamps and
   merges record-by-record, so changes on different entries from different
   devices are preserved even if both edits happened while offline.
2. **Switch to `rclone bisync`** if you want filesystem-level conflict
   preservation (`...conflict1`, `...conflict2`) as a backstop.

**Force a flush before shutdown:**

```bash
systemctl --user stop rclone-gdrive.service
```

The `ExecStop` unmounts cleanly, which flushes pending uploads. `loginctl
enable-linger` plus normal shutdown also flushes correctly.

---

## Note: desktop-environment agnostic

Because the mount is a systemd user service, it is independent of KDE Plasma.
If you later rebase Bazzite to GNOME, Sway, Hyprland, or any other DE/WM, the
mount and KeePassXC sync continue to work without reconfiguring "Online
Accounts" or any DE-specific cloud integration.

---

## Uninstall / rollback

```bash
systemctl --user disable --now rclone-gdrive.service
rm ~/.config/systemd/user/rclone-gdrive.service
systemctl --user daemon-reload
fusermount3 -u ~/GDrive 2>/dev/null
rmdir ~/GDrive
rclone config       # then 'd' to delete the gdrive remote
brew uninstall rclone
```

Your `.kdbx` remains on Google Drive and can be downloaded via the web UI.
