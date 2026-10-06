#!/bin/bash

# shellcheck source=../scripts/functions.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

. ../scripts/functions.sh

SOURCE="$DIR"
DESTINATION="$HOME/.config/gh"

info "Setting up GitHub CLI..."

mkdir -p "$DESTINATION"
scopy "$SOURCE/config.yml" "$DESTINATION/config.yml" || exit 1

success "Finished configuring GitHub CLI."
