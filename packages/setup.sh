#!/bin/bash

DIR=$(dirname "$0")
cd "$DIR" || exit 1

. ../scripts/functions.sh

sudo -v

info "Installing Brew packages from brewfile..."
brew bundle
success "Finished installing Brew packages."

# App Store apps are separate because `brew bundle` fails when the Mac is not signed in to
# the App Store; that should only warn, not abort bootstrap.
if [ -f Brewfile.appstore ]; then
    info "Installing App Store apps..."
    if brew bundle --file=Brewfile.appstore; then
        success "Finished installing App Store apps."
    else
        substep_error "Some App Store apps failed. Sign in to the App Store and re-run packages/setup.sh."
    fi
fi
