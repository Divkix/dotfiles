#!/bin/bash

# shellcheck source=../scripts/functions.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

. ../scripts/functions.sh

SOURCE="$DIR"
DESTINATION="$HOME/.config/btop"

info "Setting up btop..."

mkdir -p "$DESTINATION"
scopy "$SOURCE/btop.conf" "$DESTINATION/btop.conf" || exit 1

success "Finished configuring btop."
