#!/bin/bash

DIR=$(dirname "$0")
cd "$DIR"

. ../scripts/functions.sh

SOURCE="$(realpath .)"
DESTINATION="$(realpath $HOME/.config/)"

info "Setting up Starship..."

find * -name "starship.toml*" | while read fn; do
    scopy "$SOURCE/$fn" "$DESTINATION/$fn"
done

success "Finished configuring Starship 🚀"
