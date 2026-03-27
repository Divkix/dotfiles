# update.sh hardening design

## Goal

Make `./update.sh` safe to run as the authoritative mirror from the live machine back into the repo.

The new contract is explicit: every managed path in the repo mirrors the current live source. If a managed live source is missing, the repo copy is removed on purpose. If collection or generation fails before apply, the repo stays unchanged. If apply fails after changes start, touched targets are rolled back; if rollback itself fails, the script reports that the repo may be partially updated.

## Current problems

- `update.sh` writes straight into tracked files and directories.
- `sync_directory()` deletes repo directories before it proves the live source exists.
- Missing required files abort late, after earlier paths may already be updated.
- `tests/test_dotfiles.py` only covers a narrow happy path for `update.sh`.

## Design

### Mirror model

`update.sh` will manage a curated target list through explicit staging helpers. Each managed target falls into one of these categories:

- `file`: copy one live file into the staged mirror if it exists
- `dir`: mirror one live directory tree into the staged mirror if it exists
- `generated`: write staged output produced by a command such as `fisher list` or `brew bundle dump`
- `pruned`: track a repo-only path that should always be removed during apply

If a live file or directory does not exist, the staged mirror simply omits it. During apply, the repo target is deleted. That makes the pure mirror policy deliberate instead of accidental.

### Two-phase execution

`update.sh` will run in two phases.

1. `snapshot`
   - Create a temp workspace.
   - Copy every managed live source into a staged repo tree under the temp workspace.
   - Generate staged artifacts for Fisher and Homebrew inside the temp workspace.
   - If any required command fails, abort before touching tracked repo files.

2. `apply`
   - Replace each managed repo target with the staged version when it exists.
   - Delete each managed repo target when the staged version is absent.
   - Track backups of touched targets so an apply failure can restore the previous state.

### Failure handling

- Use `set -euo pipefail`.
- Use `trap` cleanup for repo-local temp directories, keeping the hidden `.update.sh.*` artifacts only when rollback itself fails.
- Keep collection failures and generation failures in the snapshot phase only.
- Treat apply as transactional at the target level by moving current targets into a backup area before replacing them.
- Restore touched targets from backup if apply fails midway, and surface rollback failures explicitly.

### Managed targets

The repo targets remain the current curated set:

- `fish/config.fish`
- `fish/functions/fish_prompt.fish`
- `fish/functions/fish_greeting.fish`
- `fish/functions/fish_prompt_loading_indicator.fish`
- `fish/conf.d/abbr.fish`
- `fish/conf.d/alias.fish`
- `claude/settings.json`
- `claude/CLAUDE.md`
- `claude/agents/`
- `claude/commands/`
- `claude/claude.json`
- `opencode/opencode.json`
- `opencode/AGENTS.md`
- `opencode/dcp.jsonc`
- `opencode/prompts/`
- `ghostty/config`
- `fisher/fisher install.list`
- `git/.gitconfig`
- `git/.gitignore_global`
- `ssh/config`
- `gnupg/gpg.conf`
- `gnupg/gpg-agent.conf`
- `packages/Brewfile`
- `starship/starship.toml`

The legacy repo path `opencode/agent/` stays intentionally removed.

## Testing strategy

Add regression tests in `tests/test_dotfiles.py` for:

- pure mirror pruning when live managed files or directories are missing
- no tracked repo mutation when Fisher generation fails
- no tracked repo mutation when Homebrew Brewfile generation fails
- correct Fisher manifest output for non-empty plugin lists
- Brewfile generation on the happy path
- apply rollback restoring already-mutated targets when a staged move fails
- degraded rollback-failure reporting, including preserved repo-local `.update.sh.*` artifacts and the expected partial repo state
- repo-local `.update.sh.*` cleanup on success and on snapshot-phase failures
- continued support for the existing curated OpenCode backup

The TDD sequence is strict: write each failing test, watch it fail, then implement the minimum script change to pass.

## Documentation

Update `README.md` so `./update.sh` is described as a curated mirror of the live machine, including delete-on-missing semantics, snapshot-phase failure safety, and explicit rollback-failure reporting during degraded apply failures.
