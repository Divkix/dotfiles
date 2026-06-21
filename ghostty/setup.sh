#!/bin/bash

# shellcheck source=../scripts/functions.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

. ../scripts/functions.sh

SOURCE="$DIR"
DESTINATION="$HOME/.config/ghostty"

info "Setting up Ghostty..."

mkdir -p "$DESTINATION"
scopy "$SOURCE/config" "$DESTINATION/config" || exit 1

if command -v duti >/dev/null 2>&1; then
    substep_info "Setting Ghostty as the default terminal..."
    if duti -s com.mitchellh.ghostty public.unix-executable all; then
        substep_success "Ghostty is now the default terminal."
    else
        substep_error "Failed setting Ghostty as the default terminal."
    fi
else
    substep_info "duti not found; skipping default terminal assignment."
fi

success "Finished configuring Ghostty."
