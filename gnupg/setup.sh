#! /usr/bin/env sh

DIR=$(dirname "$0")
cd "$DIR"

. ../scripts/functions.sh

SOURCE="$(realpath .)"
DESTINATION="$(realpath $HOME/.gnupg/)"

info "Configuraing gnupg..."

find . -name "gpg*" | while read fn; do
    fn=$(basename $fn)
    scopy "$SOURCE/$fn" "$DESTINATION/$fn"
done
clear_broken_symlinks "$DESTINATION"

success "Finished configuring gnupg."
