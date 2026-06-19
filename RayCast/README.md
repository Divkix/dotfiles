# Raycast Backup

A password-encrypted export of Raycast settings & data. Unlike the rest of this repo, it is a
manual backup artifact: `bootstrap.sh` does **not** restore it and `update.sh` does **not**
refresh it.

## Restore (new machine)

1. Install Raycast (already in `packages/Brewfile`).
2. Raycast → Settings → Advanced → **Import**, pick the `.rayconfig` file here, enter the password.

## Refresh the backup

Raycast → Settings → Advanced → **Export**, set a password, and save the `.rayconfig` into this
folder. Commit the new file and delete the stale one so only the current export is tracked.

> Note: the checked-in export predates the migration to Raycast v2 — re-export from v2 to refresh it.
