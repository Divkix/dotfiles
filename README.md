# dotfiles

[![CI](https://github.com/Divkix/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/Divkix/dotfiles/actions/workflows/ci.yml)

This is my setup for my Macbook Pro (M4 Pro) for development purposes.

Previously used on:
- MacBook Air (2020, M1)

## Managed config

`bootstrap.sh` applies the repo-managed version of these configs:

- `fish/`
- `fisher/`
- `git/`
- `ssh/`
- `omp/` — Oh My Pi agent (`~/.omp/agent`)
- `ghostty/` — Ghostty terminal (`~/.config/ghostty`)
- `zed/` — Zed editor (`~/.config/zed`)
- `gnupg/`
- `starship/`

`RayCast/` is only an encrypted backup artifact. It is not restored by `bootstrap.sh`.

Each tool is backed up as a curated, secret-free subset of its live config:

- **OMP** (`~/.omp/agent`): `config.yml` (with secret-bearing values such as `searxng.token`,
  `searxng.basicPassword`, and `auth.broker.token` blanked to `""`; booleans and numbers are
  left as-is). Provider credentials live in the `agent.db` auth store, sessions and history are
  machine state, and `models.yml` can pin literal API keys — none of those are synced.
- **Ghostty** (`~/.config/ghostty`): `config`. `ghostty/setup.sh` also sets Ghostty as the
  default terminal via `duti`.
- **Zed** (`~/.config/zed`): `settings.json` and `keymap.json`. The prompt-library database,
  `settings_backup.json`, and `themes/` are excluded as machine state. No redaction is needed
  because Zed stores provider API keys in the macOS keychain, not in `settings.json`. Extensions
  are synced declaratively through the `auto_install_extensions` block in `settings.json` (Zed's
  recommended approach — it auto-installs them on launch). `update.sh` **regenerates that block
  on every run** from the live installed-extensions directory
  (`~/Library/Application Support/Zed/extensions/installed/`), so just install or remove
  extensions in Zed and run `./update.sh` — no manual ID editing. The regeneration is a full
  rebuild, so manual `"id": false` ("never install") pins are not preserved. The compiled
  extension binaries under `~/Library/Application Support/Zed/` are machine state and are not
  synced.

Because the repo is public, `update.sh` sanitizes on capture: it blanks secret-bearing
`set -gx` exports in `fish/config.fish` and secret values in `omp/config.yml`, so keys and
tokens never get committed.

Local install artifacts such as `node_modules/`, package manager files, and other machine-specific state are intentionally excluded.

## Installation
These steps must be followed to ensure smooth installation:

### Install homebrew
Head over to https://brew.sh and install the latest version of homebrew by copying the command from the given text box.

### Run the bootstrap.sh file

`bootstrap.sh` prompts for sudo, installs packages from `packages/Brewfile`, applies the managed config listed above, and sets fish as the login shell if needed.

Use this command to install the dotfiles setup:

`./bootstrap.sh`

### Post-install manual steps

A few things bootstrap intentionally cannot restore:

- **OMP provider credentials**: `omp/config.yml` ships without them — stored credentials live in
  `~/.omp/agent/agent.db` (not in this repo). Run `omp` and `/login <provider>` on a fresh machine.
- **Raycast**: import the encrypted backup from `RayCast/` via the Raycast app
  (Settings → Advanced → Import). See `RayCast/README.md`.

## Updating the repo from the current machine

Run this to sync the live machine back into the repo:

`./update.sh`

This builds a temp mirror of the managed live config, updates the Fisher manifest, and regenerates `packages/Brewfile` before applying the changes to the repo. If a managed live file or directory is missing, `./update.sh` removes the corresponding repo snapshot on purpose. If snapshot or generation fails, the repo stays unchanged and the hidden repo-local `.update.sh.*` temp directory is cleaned up. If apply fails after changes start, `./update.sh` tries to roll touched targets back; if rollback also fails, it reports that the repo may be partially updated and keeps that repo-local `.update.sh.*` artifacts path for inspection.

## Tests

Run the regression tests with:

`python3 -m unittest discover -s tests -p 'test_*.py' -v`
