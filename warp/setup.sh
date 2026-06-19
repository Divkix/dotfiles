#!/bin/bash

# shellcheck source=../scripts/functions.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

. ../scripts/functions.sh

SOURCE="$DIR"
DESTINATION="$HOME/.warp"

info "Setting up Warp..."

mkdir -p "$DESTINATION"

scopy "$SOURCE/settings.toml" "$DESTINATION/settings.toml" || exit 1
sync_tree_files "$SOURCE/default_tab_configs" "$DESTINATION/default_tab_configs" || exit 1

success "Finished configuring Warp 🚀"
