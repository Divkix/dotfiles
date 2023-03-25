#!/bin/bash

# first install fisher using fish shell
fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"

DIR=$(dirname "$0")
cd "$DIR"

. ../scripts/functions.sh

find * -name "*.list" | while read fn; do
    cmd="${fn%.*}"
    set -- $cmd
    info "Installing $1 packages..."
    while read package; do
        if [[ $package == $COMMENT ]]; then
            continue
        fi
        substep_info "Installing $package..."
        if [[ $cmd == code* ]]; then
            $cmd $package
        else
            $cmd install $package $i
        fi
    done <"$fn"
    substep_success "Finished installing $1 packages."
done
