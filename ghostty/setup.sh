#!/bin/bash

# shellcheck source=../scripts/functions.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

. ../scripts/functions.sh

SOURCE="$DIR"
DESTINATION="$HOME/.config/ghostty"

info "Setting up Ghostty..."

mkdir -p "$DESTINATION"
scopy "$SOURCE/config" "$DESTINATION/config" || exit 1

success "Finished configuring Ghostty."
