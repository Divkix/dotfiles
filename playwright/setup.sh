#!/bin/bash

# shellcheck source=../scripts/functions.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

. ../scripts/functions.sh

SOURCE="$DIR"
DESTINATION="$HOME/.playwright"

info "Setting up Playwright CLI..."

mkdir -p "$DESTINATION"
scopy "$SOURCE/cli.config.json" "$DESTINATION/cli.config.json" || exit 1

success "Finished configuring Playwright CLI."
