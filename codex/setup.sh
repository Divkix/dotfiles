#!/bin/bash

# shellcheck source=../scripts/functions.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

. ../scripts/functions.sh

SOURCE="$DIR"
DESTINATION="$HOME/.codex"

info "Setting up Codex..."

mkdir -p "$DESTINATION"

# config.toml in the repo is sanitized (per-project trust paths are stripped). Only seed it
# on a fresh machine; never clobber a live config that already holds trust grants / state.
if [ -e "$DESTINATION/config.toml" ]; then
    substep_info "Preserving existing ~/.codex/config.toml."
else
    scopy "$SOURCE/config.toml" "$DESTINATION/config.toml" || exit 1
fi

sync_tree_files "$SOURCE/rules" "$DESTINATION/rules" || exit 1

success "Finished configuring Codex 🚀"
