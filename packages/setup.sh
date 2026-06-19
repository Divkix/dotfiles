#!/bin/bash

DIR=$(dirname "$0")
cd "$DIR"

. ../scripts/functions.sh

sudo -v

info "Installing Brew packages from brewfile..."
brew bundle
success "Finished installing Brew packages."
