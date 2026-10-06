#!/bin/bash

# shellcheck source=../scripts/functions.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

. ../scripts/functions.sh

SOURCE="$DIR"
DESTINATION="$HOME/.config/worktrunk"

info "Setting up Worktrunk..."

mkdir -p "$DESTINATION"
scopy "$SOURCE/config.toml" "$DESTINATION/config.toml" || exit 1

success "Finished configuring Worktrunk."
