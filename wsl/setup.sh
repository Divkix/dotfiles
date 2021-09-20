#! /usr/bin/env bash

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

success "Finished configuring WSL"
