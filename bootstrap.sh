#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

. scripts/functions.sh

cleanup_sudo_keepalive() {
    if [ -n "${SUDO_KEEPALIVE_PID:-}" ]; then
        kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
        wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    fi
}

info "Prompting for sudo password..."
if sudo -v; then
    # Keep-alive: update existing `sudo` time stamp until `setup.sh` has finished
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done >/dev/null 2>&1 < /dev/null &
    SUDO_KEEPALIVE_PID="$!"
    trap cleanup_sudo_keepalive EXIT
    success "Sudo credentials updated."
else
    error "Failed to obtain sudo credentials."
    exit 1
fi

# Package control must be executed first in order for the rest to work
if ! bash "./packages/setup.sh"; then
    cleanup_sudo_keepalive
    error "Failed running ./packages/setup.sh"
    exit 1
fi

while IFS= read -r setup; do
    if ! bash "$setup"; then
        cleanup_sudo_keepalive
        error "Failed running $setup"
        exit 1
    fi
done < <(find . -mindepth 2 -maxdepth 2 -name "setup.sh" ! -path "./packages/*" | sort)

cleanup_sudo_keepalive
success "Finished installing Dotfiles"
