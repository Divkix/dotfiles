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
scopy "$SOURCE/CLAUDE.md" "$DESTINATION/CLAUDE.md" || exit 1
sync_tree_files "$SOURCE/agents" "$DESTINATION/agents" || exit 1
sync_tree_files "$SOURCE/commands" "$DESTINATION/commands" || exit 1
scopy "$SOURCE/claude.json" "$HOME/.claude.json" || exit 1

success "Finished configuring Claude Code 🚀"
