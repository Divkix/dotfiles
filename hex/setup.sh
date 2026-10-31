#!/bin/bash

# shellcheck source=../scripts/functions.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

. ../scripts/functions.sh

SOURCE="$DIR"
CONFIG_DESTINATION="$HOME/.config/hex"
SETTINGS_DESTINATION="$HOME/Library/Application Support/hex/settings.json"

info "Setting up Hex..."

# Hex writes AGENTS.md, hex.d.ts and tsconfig.json beside the config itself; only the user's
# transformations script is restored.
scopy "$SOURCE/hex.config.ts" "$CONFIG_DESTINATION/hex.config.ts" || exit 1

# settings.json is captured with __HOME__ in place of the home directory so it is portable.
settings_tmp="$(mktemp)"
if ! sed "s#__HOME__#$HOME#g" "$SOURCE/settings.json" > "$settings_tmp"; then
    rm -f "$settings_tmp"
    substep_error "Failed rendering settings.json."
    exit 1
fi
scopy "$settings_tmp" "$SETTINGS_DESTINATION"
status=$?
rm -f "$settings_tmp"
[ "$status" -eq 0 ] || exit 1

success "Finished configuring Hex."
