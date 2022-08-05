#!/bin/bash

DIR=$(dirname "$0")
cd "$DIR"

. ../scripts/functions.sh

SOURCE="$(realpath .)"
DESTINATION="$(realpath $HOME/.gnupg/)"

info "Configuraing gnupg..."

if [! -d "/path/to/dir" ] && echo "Directory $HOME/.gnupg does not exists creating..." && mkdir $DESTINATION

find . -name "gpg*" | while read fn; do
    fn=$(basename $fn)
    symlink "$SOURCE/$fn" "$DESTINATION/$fn"
done
clear_broken_symlinks "$DESTINATION"

success "Finished configuring gnupg."
