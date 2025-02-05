#!/bin/bash

DIR=$(dirname "$0")
cd "$DIR"

. ../scripts/functions.sh

SOURCE="$(realpath .)"
DESTINATION="$(realpath $HOME/.config/ghostty/)"

info "Setting up Ghostty..."

find * -name "config*" | while read fn; do
    scopy "$SOURCE/$fn" "$DESTINATION/$fn"
done

success "Finished configuring Starship 🚀"
