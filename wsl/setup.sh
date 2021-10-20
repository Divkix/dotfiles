#! /usr/bin/env sh

DIR=$(dirname "$0")
cd "$DIR"

. ../scripts/functions.sh

SOURCE="$(realpath ./)"
DESTINATION="$(realpath /etc/)"

CONFIG_FILE="wsl.conf"

SOURCE_FILE="$SOURCE/$CONFIG_FILE"
DESTINATION_FILE="$DESTINATION/$CONFIG_FILE"

info "Setting up WSL config file..."
scopy "$SOURCE_FILE" "$DESTINATION_FILE"

info "Setting up fish shell for WSL..."
fish -c 'set -Ux WINDOWS_USER_NAME (string split -f2 -r -m1 \\ (/mnt/c/Windows/System32/cmd.exe /c echo %USERPROFILE% | string trim -c \r))' &>/dev/null

success "Finished configuring WSL"
