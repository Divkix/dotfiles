#!/bin/bash

DIR=$(dirname "$0")
cd "$DIR" || exit 1

. ../scripts/functions.sh

SOURCE="$(realpath .)"
DESTINATION="$(realpath "$HOME")"

info "Configuring git..."

while IFS= read -r fn; do
    fn=$(basename "$fn")
    scopy "$SOURCE/$fn" "$DESTINATION/$fn" || exit 1
done < <(find . -name ".git*")

success "Finished configuring git."
