#!/bin/bash

# shellcheck source=../scripts/functions.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

. ../scripts/functions.sh

SOURCE="$DIR"
DESTINATION="$HOME/.codex"

info "Setting up Codex..."

mkdir -p "$DESTINATION"

scopy "$SOURCE/config.toml" "$DESTINATION/config.toml" || exit 1
scopy "$SOURCE/herdr-agent-state.sh" "$DESTINATION/herdr-agent-state.sh" || exit 1
chmod 755 "$DESTINATION/herdr-agent-state.sh"

# hooks.json is captured with __HOME__ in place of the home directory so it is portable.
hooks_tmp="$(mktemp)"
if ! sed "s#__HOME__#$HOME#g" "$SOURCE/hooks.json" > "$hooks_tmp"; then
    rm -f "$hooks_tmp"
    substep_error "Failed rendering hooks.json."
    exit 1
fi
scopy "$hooks_tmp" "$DESTINATION/hooks.json"
status=$?
rm -f "$hooks_tmp"
[ "$status" -eq 0 ] || exit 1

success "Finished configuring Codex. Codex will ask you to trust the session hook on first launch."
