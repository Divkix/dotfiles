#!/bin/bash

DIR=$(dirname "$0")
cd "$DIR"

. ../scripts/functions.sh

SOURCE="$(realpath .)"
DESTINATION="$(realpath $HOME/.claude)"

info "Setting up Claude Code..."

find * -name "*" | while read fn; do
    scopy "$SOURCE/$fn" "$DESTINATION/$fn"
done

success "Finished configuring Claude Code 🚀"
