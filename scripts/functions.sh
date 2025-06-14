#!/bin/bash

set -euo pipefail

scopy() {
    OVERWRITTEN=""
    if [ -e "$2" ] || [ -h "$2" ]; then
        OVERWRITTEN="(Overwritten)"
        if ! sudo rm -r "$2"; then
            substep_error "Failed to remove existing file(s) at $2."
        fi
    fi

    if sudo cp "$1" "$2"; then
        substep_success "Copied $1 to $2. $OVERWRITTEN"
    else
        substep_error "Copying $1 to $2 failed."
    fi
}

# Took these printing functions from https://github.com/Sajjadhosn/dotfiles
coloredEcho() {
    local exp="$1"
    local color="$2"
    local arrow="$3"
    if ! [[ $color =~ '^[0-9]$' ]]; then
        case $(printf $color | tr '[:upper:]' '[:lower:]') in
        black) color=0 ;;
        red) color=1 ;;
        green) color=2 ;;
        yellow) color=3 ;;
        blue) color=4 ;;
        magenta) color=5 ;;
        cyan) color=6 ;;
        white | *) color=7 ;; # white or invalid color
        esac
    fi
    tput bold
    tput setaf "$color"
    printf "$arrow $exp\n"
    tput sgr0
}

info() {
    coloredEcho "$1" blue "========>"
}

success() {
    coloredEcho "$1" green "========>"
}

error() {
    coloredEcho "$1" red "========>"
}

substep_info() {
    coloredEcho "$1" magenta "===="
}

substep_success() {
    coloredEcho "$1" cyan "===="
}

substep_error() {
    coloredEcho "$1" red "===="
}

note() {
    coloredEcho "\n$1" red "NOTE:"
}
