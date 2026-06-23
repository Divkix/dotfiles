#!/bin/bash

# shellcheck source=../scripts/functions.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

. ../scripts/functions.sh

SOURCE="$DIR"
DESTINATION="$HOME/.config/zed"

info "Setting up Zed..."

mkdir -p "$DESTINATION"

scopy "$SOURCE/settings.json" "$DESTINATION/settings.json" || exit 1
scopy "$SOURCE/keymap.json" "$DESTINATION/keymap.json" || exit 1

success "Finished configuring Zed 🚀"
