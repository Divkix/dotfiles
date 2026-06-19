#!/bin/bash

# shellcheck source=../scripts/functions.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

. ../scripts/functions.sh

SOURCE="$DIR"
DESTINATION="$HOME/.claude"

info "Setting up Claude Code..."

mkdir -p "$DESTINATION"

scopy "$SOURCE/settings.json" "$DESTINATION/settings.json" || exit 1
sync_tree_files "$SOURCE/agents" "$DESTINATION/agents" || exit 1
sync_tree_files "$SOURCE/commands" "$DESTINATION/commands" || exit 1

# Claude's global instructions are the single canonical AGENTS.md managed by the opencode
# module. Link to it at runtime (resolved via $HOME, so it stays portable). opencode/setup.sh
# creates the target; if it has not run yet this link is briefly dangling, which is harmless.
ln -sfn "$HOME/.config/opencode/AGENTS.md" "$DESTINATION/CLAUDE.md" || exit 1
substep_success "Linked ~/.claude/CLAUDE.md -> ~/.config/opencode/AGENTS.md"

# ~/.claude.json is machine state (project paths, costs, userID) and is intentionally
# not managed here. Claude Code regenerates it; user-facing prefs live in settings.json.

success "Finished configuring Claude Code 🚀"
