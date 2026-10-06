#!/bin/bash

# shellcheck source=../scripts/functions.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

. ../scripts/functions.sh

SOURCE="$DIR"
DESTINATION="$HOME/.claude"
AGENTS_MD="$HOME/.omp/agent/AGENTS.md"

info "Setting up Claude Code..."

mkdir -p "$DESTINATION/hooks"

# settings.json is captured with __HOME__ in place of the home directory so it is portable.
settings_tmp="$(mktemp)"
if ! sed "s#__HOME__#$HOME#g" "$SOURCE/settings.json" > "$settings_tmp"; then
    rm -f "$settings_tmp"
    substep_error "Failed rendering settings.json."
    exit 1
fi
scopy "$settings_tmp" "$DESTINATION/settings.json"
status=$?
rm -f "$settings_tmp"
[ "$status" -eq 0 ] || exit 1

scopy "$SOURCE/hooks/herdr-agent-state.sh" "$DESTINATION/hooks/herdr-agent-state.sh" || exit 1
chmod 755 "$DESTINATION/hooks/herdr-agent-state.sh"

# CLAUDE.md is a link to the OMP global rules (omp/AGENTS.md) so both agents share one file.
# A real file already at that path is kept as CLAUDE.md.bak rather than overwritten.
if [ -e "$DESTINATION/CLAUDE.md" ] && [ ! -L "$DESTINATION/CLAUDE.md" ]; then
    mv "$DESTINATION/CLAUDE.md" "$DESTINATION/CLAUDE.md.bak" || exit 1
    substep_info "Kept existing CLAUDE.md as CLAUDE.md.bak."
fi
ln -sfn "$AGENTS_MD" "$DESTINATION/CLAUDE.md" || exit 1
substep_success "Linked CLAUDE.md to $AGENTS_MD."

success "Finished configuring Claude Code."
