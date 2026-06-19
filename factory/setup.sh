#!/bin/bash

# shellcheck source=../scripts/functions.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

. ../scripts/functions.sh

SOURCE="$DIR"
DESTINATION="$HOME/.factory"

info "Setting up Factory (droid)..."

mkdir -p "$DESTINATION"

# settings.json in the repo has customModels API keys redacted. Only seed it on a fresh
# machine so we never overwrite a live settings.json that holds real API keys.
if [ -e "$DESTINATION/settings.json" ]; then
    substep_info "Preserving existing ~/.factory/settings.json (keeps live API keys)."
else
    scopy "$SOURCE/settings.json" "$DESTINATION/settings.json" || exit 1
fi

scopy "$SOURCE/mcp.json" "$DESTINATION/mcp.json" || exit 1
sync_tree_files "$SOURCE/droids" "$DESTINATION/droids" || exit 1

# Factory shares the single canonical AGENTS.md managed by the opencode module. Link to it
# at runtime (resolved via $HOME). opencode/setup.sh creates the target.
ln -sfn "$HOME/.config/opencode/AGENTS.md" "$DESTINATION/AGENTS.md" || exit 1
substep_success "Linked ~/.factory/AGENTS.md -> ~/.config/opencode/AGENTS.md"

success "Finished configuring Factory 🚀"
