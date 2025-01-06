#!/bin/bash

DIR=$(dirname "$0")
cd "$DIR"

. ../scripts/functions.sh

SOURCE="$(realpath .)"
DESTINATION="$(realpath $HOME/.config/neofetch)"

info "Setting up Neofetch..."

find * -name "*.conf" | while read fn; do
    scopy "$SOURCE/$fn" "$DESTINATION/$fn"
done

success "Finished configuring Neofetch"
