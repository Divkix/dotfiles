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
- `claude/` — Claude Code (`~/.claude`)
- `opencode/` — OpenCode (`~/.config/opencode`)
- `factory/` — Factory / droid (`~/.factory`)
- `codex/` — Codex (`~/.codex`)
- `ghostty/` — Ghostty terminal (`~/.config/ghostty`)
- `gnupg/`
- `starship/`

The AI agents share a single canonical instruction file, `opencode/AGENTS.md`. `bootstrap.sh`
symlinks `~/.claude/CLAUDE.md` and `~/.factory/AGENTS.md` to it at runtime, so it stays a
single source of truth and the repo never stores a machine-specific absolute symlink.

`RayCast/` is only an encrypted backup artifact. It is not restored by `bootstrap.sh`.

Each agent/tool is backed up as a curated, secret-free subset of its live config:

- **Claude** (`~/.claude`): `settings.json`, `agents/`, `commands/`. `CLAUDE.md` is the shared
  symlink above. `~/.claude.json` is **not** managed — it is machine state (project paths,
  costs, userID) and would leak in this public repo.
- **OpenCode** (`~/.config/opencode`): `opencode.json`, `AGENTS.md`, `dcp.jsonc`, `prompts/`,
  `instructions/`.
- **Factory** (`~/.factory`): `settings.json` (with `customModels[].apiKey` redacted to `""`),
  `mcp.json`, `droids/`. Auth, sessions, logs, cache, and history are excluded.
- **Codex** (`~/.codex`): `config.toml` (with `[projects."..."]` trust paths stripped) and
  `rules/`. Auth, history, and SQLite state are excluded.
- **Ghostty** (`~/.config/ghostty`): `config`. `ghostty/setup.sh` also sets Ghostty as the
  default terminal via `duti`.

Because the repo is public, `update.sh` sanitizes on capture: it blanks Factory API keys and
strips Codex per-project paths so secrets and private repo paths never get committed. For the
same reason, Factory `settings.json` and Codex `config.toml` are only seeded on a fresh machine
(never overwritten), so a live config holding a real key or trust grants is preserved.

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

- **Factory DeepSeek key**: `factory/settings.json` ships with `customModels[].apiKey` blanked.
  Re-enter the DeepSeek API key in Factory (Settings → Models) on a fresh machine.
- **Raycast**: import the encrypted backup from `RayCast/` via the Raycast app
  (Settings → Advanced → Import). See `RayCast/README.md`.

## Updating the repo from the current machine

Run this to sync the live machine back into the repo:

`./update.sh`

This builds a temp mirror of the managed live config, updates the Fisher manifest, and regenerates `packages/Brewfile` before applying the changes to the repo. If a managed live file or directory is missing, `./update.sh` removes the corresponding repo snapshot on purpose. If snapshot or generation fails, the repo stays unchanged and the hidden repo-local `.update.sh.*` temp directory is cleaned up. If apply fails after changes start, `./update.sh` tries to roll touched targets back; if rollback also fails, it reports that the repo may be partially updated and keeps that repo-local `.update.sh.*` artifacts path for inspection.

## Tests

Run the regression tests with:

`python3 -m unittest discover -s tests -p 'test_*.py' -v`
