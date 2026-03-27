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
- `claude/`
- `opencode/`
- `ghostty/`
- `gnupg/`
- `starship/`

`RayCast/` is only an encrypted backup artifact. It is not restored by `bootstrap.sh`.

OpenCode is backed up as a curated subset of `~/.config/opencode`:

- `opencode.json`
- `AGENTS.md`
- `dcp.jsonc`
- `prompts/`

Local install artifacts such as `node_modules/`, package manager files, and other machine-specific state are intentionally excluded.

## Installation
These steps must be followed to ensure smooth installation:

### Install homebrew
Head over to https://brew.sh and install the latest version of homebrew by copying the command from the given text box.

### Run the bootstrap.sh file

`bootstrap.sh` prompts for sudo, installs packages from `packages/Brewfile`, applies the managed config listed above, and sets fish as the login shell if needed.

Use this command to install the dotfiles setup:

`./bootstrap.sh`

## Updating the repo from the current machine

Run this to sync the live machine back into the repo:

`./update.sh`

This refreshes the tracked config files, updates the Fisher manifest, and regenerates `packages/Brewfile`.

## Tests

Run the regression tests with:

`python3 -m unittest discover -s tests -p 'test_*.py' -v`
