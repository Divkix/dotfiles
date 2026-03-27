#!/bin/bash

# shellcheck source=../scripts/functions.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

. ../scripts/functions.sh

SOURCE="$DIR"
DESTINATION="$HOME/.config/opencode"

info "Setting up Opencode..."

mkdir -p "$DESTINATION"

scopy "$SOURCE/opencode.json" "$DESTINATION/opencode.json" || exit 1
scopy "$SOURCE/AGENTS.md" "$DESTINATION/AGENTS.md" || exit 1

if [ -f "$SOURCE/dcp.jsonc" ]; then
    scopy "$SOURCE/dcp.jsonc" "$DESTINATION/dcp.jsonc" || exit 1
else
    rm -f "$DESTINATION/dcp.jsonc" || exit 1
fi

sync_tree_files "$SOURCE/prompts" "$DESTINATION/prompts" || exit 1
rm -rf "$DESTINATION/agent" || exit 1

success "Finished configuring Opencode 🚀"
