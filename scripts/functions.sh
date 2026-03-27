#!/bin/bash

scopy() {
    local source="$1"
    local destination="$2"
    local destination_dir
    local overwritten=""
    local temp_file
    local owner

    if [ ! -e "$source" ] && [ ! -h "$source" ]; then
        substep_error "Source $source does not exist."
        return 1
    fi

    if [ -d "$source" ]; then
        substep_error "scopy does not copy directories: $source"
        return 1
    fi

    destination_dir="$(dirname "$destination")"
    if ! mkdir -p "$destination_dir"; then
        substep_error "Failed to create parent directory for $destination."
        return 1
    fi

    if [ -e "$destination" ] || [ -h "$destination" ]; then
        overwritten="(Overwritten)"
    fi

    if ! temp_file="$(mktemp)"; then
        substep_error "Failed to create a temporary file for $destination."
        return 1
    fi

    if ! cp "$source" "$temp_file"; then
        rm -f "$temp_file"
        substep_error "Copying $source to $destination failed."
        return 1
    fi

    if ! mv -f "$temp_file" "$destination"; then
        if ! sudo mv -f "$temp_file" "$destination"; then
            rm -f "$temp_file"
            substep_error "Copying $source to $destination failed."
            return 1
        fi

        owner="$(id -u):$(id -g)"
        if ! sudo chown "$owner" "$destination"; then
            substep_error "Restoring ownership for $destination failed."
            return 1
        fi
    fi

    substep_success "Copied $source to $destination. $overwritten"
}

copy_tree_files() {
    local source_root="$1"
    local destination_root="$2"
    local source_file
    local relative_path

    if [ ! -d "$source_root" ]; then
        substep_error "Source directory $source_root does not exist."
        return 1
    fi

    while IFS= read -r source_file; do
        relative_path="${source_file#"$source_root"/}"
        scopy "$source_file" "$destination_root/$relative_path" || return 1
    done < <(find "$source_root" -type f)
}

sync_tree_files() {
    local source_root="$1"
    local destination_root="$2"

    if ! rm -rf "$destination_root"; then
        if ! sudo rm -rf "$destination_root"; then
            substep_error "Failed to replace directory $destination_root."
            return 1
        fi
    fi

    if [ ! -d "$source_root" ]; then
        return 0
    fi

    if ! mkdir -p "$destination_root"; then
        substep_error "Failed to create directory $destination_root."
        return 1
    fi

    copy_tree_files "$source_root" "$destination_root"
}

# Took these printing functions from https://github.com/Sajjadhosn/dotfiles
coloredEcho() {
    local exp="$1"
    local color="$2"
    local arrow="$3"
    if ! [[ $color =~ ^[0-9]$ ]]; then
        case $(printf '%s' "$color" | tr '[:upper:]' '[:lower:]') in
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
    printf "%s %s\n" "$arrow" "$exp"
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
