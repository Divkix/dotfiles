#!/bin/bash

DIR=$(dirname "$0")
cd "$DIR" || exit 1

. ../scripts/functions.sh

sudo -v

info "Installing Brew packages from brewfile..."
brew bundle
success "Finished installing Brew packages."
