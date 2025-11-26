#!/bin/bash

DIR=$(dirname "$0")
cd "$DIR"

. ../scripts/functions.sh

SOURCE="$(realpath .)"
DESTINATION="$(realpath $HOME/.gnupg/)"

info "Configuring gnupg..."

if [ ! -d "$DESTINATION" ]; then
    echo "Directory $DESTINATION does not exist, creating..."
    mkdir -p "$DESTINATION"
fi

find . -name "gpg*" | while read fn; do
    fn=$(basename $fn)
    scopy "$SOURCE/$fn" "$DESTINATION/$fn"
done

success "Finished configuring gnupg."
