#!/bin/bash

# shellcheck source=../scripts/functions.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

. ../scripts/functions.sh

SOURCE="$DIR"
DESTINATION="$HOME/.gnupg"

info "Configuring gnupg..."

mkdir -p "$DESTINATION"
chmod 700 "$DESTINATION"

scopy "$SOURCE/gpg.conf" "$DESTINATION/gpg.conf" || exit 1
scopy "$SOURCE/gpg-agent.conf" "$DESTINATION/gpg-agent.conf" || exit 1

chmod 600 "$DESTINATION/gpg.conf"
chmod 600 "$DESTINATION/gpg-agent.conf"

success "Finished configuring gnupg."
