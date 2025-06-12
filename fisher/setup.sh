#!/bin/bash

set -euo pipefail

# first install fisher using fish shell
fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"

DIR=$(dirname "$0")
cd "$DIR"

. ../scripts/functions.sh

COMMENT=\#*

find * -name "*.list" | while read fn; do
    cmd="${fn%.*}"
    set -- $cmd
    info "Installing $1 packages..."
    while read package; do
        if [[ $package == $COMMENT ]]; then
            continue
        fi
        substep_info "Installing $package..."
        if [[ $1 == "fisher" ]]; then
            # Use fish shell to install plugins since fisher is a fish function
            fish -c "fisher install $package"
        elif [[ $cmd == code* ]]; then
            $cmd $package
        else
            $cmd install $package
        fi
    done <"$fn"
    substep_success "Finished installing $1 packages."
done
