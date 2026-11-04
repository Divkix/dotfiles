#!/bin/bash

# shellcheck source=../scripts/functions.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

. ../scripts/functions.sh

SOURCE="$DIR"
DESTINATION="$HOME/.agent-browser"

info "Setting up agent-browser..."

mkdir -p "$DESTINATION"
scopy "$SOURCE/config.json" "$DESTINATION/config.json" || exit 1

success "Finished configuring agent-browser."
