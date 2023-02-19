#!/bin/bash

DIR=$(dirname "$0")
cd "$DIR"

. scripts/functions.sh

info "Prompting for sudo password..."
if sudo -v; then
    # Keep-alive: update existing `sudo` time stamp until `setup.sh` has finished
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done 2>/dev/null &
    success "Sudo credentials updated."
else
    error "Failed to obtain sudo credentials."
    exit 1
fi

# Package control must be executed first in order for the rest to work
./packages/setup.sh

find * -name "setup.sh" \
    -not -wholename "packages*" | while read setup; do
    ./$setup
done

# Install fisher plugins
./fisher/setup.sh

success "Finished installing Dotfiles"
