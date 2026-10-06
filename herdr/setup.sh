#!/bin/bash

# shellcheck source=../scripts/functions.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

. ../scripts/functions.sh

SOURCE="$DIR"
DESTINATION="$HOME/.config/herdr"
MANIFEST="plugins.list"

info "Setting up herdr..."

mkdir -p "$DESTINATION"
scopy "$SOURCE/config.toml" "$DESTINATION/config.toml" || exit 1

# Plugins are listed as GitHub "owner/repo[/subdir]" lines. A failing plugin is reported
# but does not stop the rest or abort bootstrap: installs need the network.
if ! command -v herdr >/dev/null 2>&1; then
    substep_error "herdr not found; skipping plugin installs."
else
    failed=0
    while IFS= read -r plugin || [ -n "$plugin" ]; do
        case "$plugin" in
        "" | \#*)
            continue
            ;;
        esac

        substep_info "Installing plugin $plugin..."
        # stdin is /dev/null so herdr cannot swallow the rest of the manifest being read.
        if ! herdr plugin install -y "$plugin" </dev/null; then
            substep_error "Failed installing plugin $plugin."
            failed=$((failed + 1))
        fi
    done <"$MANIFEST"

    if [ "$failed" -gt 0 ]; then
        substep_error "$failed herdr plugin(s) failed; re-run herdr/setup.sh later."
    fi
fi

success "Finished configuring herdr."
