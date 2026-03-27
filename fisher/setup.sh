#!/bin/bash

# shellcheck source=../scripts/functions.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

. ../scripts/functions.sh

MANIFEST="fisher install.list"

if ! fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"; then
    substep_error "Failed to bootstrap fisher."
    exit 1
fi

info "Installing fisher packages..."
while IFS= read -r package || [ -n "$package" ]; do
    case "$package" in
    "" | \#*)
        continue
        ;;
    esac

    substep_info "Installing $package..."
    if ! fish -c "fisher install $package"; then
        substep_error "Failed installing $package."
        exit 1
    fi
done <"$MANIFEST"

substep_success "Finished installing fisher packages."
