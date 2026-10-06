#!/bin/bash

# shellcheck source=../scripts/functions.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

. ../scripts/functions.sh

MANIFEST="skills.list"

info "Installing agent skills..."

agents=""
failed=0

# Manifest lines: "# agents: <agent> ..." once, then "<source> <skill> [<skill> ...]".
# A failing source is reported but does not stop the rest, and bootstrap carries on: skills
# are a convenience layer and `pnpm dlx skills add` needs the network.
while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
    "# agents: "*)
        agents="${line#\# agents: }"
        continue
        ;;
    "" | \#*)
        continue
        ;;
    esac

    read -r -a fields <<<"$line"
    source="${fields[0]}"
    names=("${fields[@]:1}")

    substep_info "Installing ${names[*]} from $source..."
    # stdin is /dev/null so pnpm cannot swallow the rest of the manifest this loop is reading.
    # shellcheck disable=SC2086 # $agents is a space-separated list of agent names
    if ! pnpm dlx skills add "$source" -g -y -s "${names[@]}" ${agents:+-a $agents} </dev/null; then
        substep_error "Failed installing skills from $source."
        failed=$((failed + 1))
    fi
done <"$MANIFEST"

if [ "$failed" -gt 0 ]; then
    substep_error "$failed skill source(s) failed; re-run skills/setup.sh later."
else
    success "Finished installing agent skills."
fi
