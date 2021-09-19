#! /usr/bin/env sh

DIR=$(dirname "$0")
cd "$DIR"

. scripts/functions.sh

# Check if distribution is WSL or not
IS_WSL_DISTRO=false
if [[ $(uname -r) =~ ^(.*)-microsoft-standard-WSL2$ ]]; then
    IS_WSL_DISTRO=true
fi

info "Prompting for sudo password..."
if sudo -v; then
    # Keep-alive: update existing `sudo` time stamp until `setup.sh` has finished
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    success "Sudo credentials updated."
else
    error "Failed to obtain sudo credentials."
    exit 1
fi

# do run some initial installtions
./scripts/initial_config.sh

# Package control must be executed first in order for the rest to work
./packages/setup.sh

find * -name "setup.sh" -not -wholename "packages*" | while read setup; do
    ./$setup
done

success "Finished installing Dotfiles"

# Check if distribution is WSL or not
# If yes, then do additional setup
if [[ "$IS_WSL_DISTRO" == "true" ]]; then
    ./wsl/setup.sh
    note "A WSL system has been detected, a restart of WSL using 'wsl --shutdown' from command prompt is required!"
fi
