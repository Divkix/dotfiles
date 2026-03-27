#!/bin/bash

# shellcheck source=../scripts/functions.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

. ../scripts/functions.sh

SOURCE="$DIR"
DESTINATION="$HOME/.ssh"

info "Configuring SSH..."

mkdir -p "$DESTINATION"
chmod 700 "$DESTINATION"

scopy "$SOURCE/config" "$DESTINATION/config" || exit 1
chmod 600 "$DESTINATION/config"

success "Finished configuring SSH."
