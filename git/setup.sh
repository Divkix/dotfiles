#!/bin/bash

DIR=$(dirname "$0")
cd "$DIR"

. ../scripts/functions.sh

SOURCE="$(realpath .)"
DESTINATION="$(realpath $HOME)"

info "Configuring git..."

find . -name ".git*" | while read fn; do
    fn=$(basename $fn)
    scopy "$SOURCE/$fn" "$DESTINATION/$fn"
done

success "Finished configuring git."
