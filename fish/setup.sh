#! /usr/bin/env bash

DIR=$(dirname "$0")
cd "$DIR"

. ../scripts/functions.sh

mkdir -p "$HOME/.config/fish"

SOURCE="$(realpath .)"
DESTINATION="$(realpath $HOME/.config/fish)"

info "Setting up fish shell..."

substep_info "Creating fish config folders..."
mkdir -p "$DESTINATION/functions"
mkdir -p "$DESTINATION/completions"
mkdir -p "$DESTINATION/conf.d"

find * -name "*fish*" | while read fn; do
    symlink "$SOURCE/$fn" "$DESTINATION/$fn"
done
clear_broken_symlinks "$DESTINATION"

set_fish_shell() {
    if grep --quiet fish <<< "$SHELL"; then
        success "Fish shell is already set up."
    else
        substep_info "Checking if fish is installed..."
        if chsh -l | grep -q "fish"; then
            substep_info "Fish shell already installed"
        else
            substep_error "Fish shell is not installed. Setting it up..."
            echo $(which fish) | sudo tee -a /etc/shells
        fi
        substep_info "Changing shell to fish"
        if sudo chsh -s $(which fish) $(whoami); then
            substep_success "Changed shell to fish"
        else
            substep_error "Failed changing shell to fish"
            return 2
        fi
    fi

    substep_info "Installing fisher..."
    fish -c "curl -sL https://git.io/fisher | source && \
        fisher install jorgebucaran/fisher" &>/dev/null
    if fish -c "fisher -v" &>/dev/null; then
        substep_success "Installed fisher succesfully!"
    else
        substep_error "Failed to install fisher!"
    fi

    substep_info "Installing fisher plugins..."
    fish -c "fisher install \
        jorgebucaran/fish-bax \
        oh-my-fish/plugin-pj \
        oh-my-fish/plugin-license \
        markcial/upto \
        jethrokuan/z \
        jorgebucaran/gitio.fish \
        gazorby/fish-abbreviation-tips" &>/dev/null
    if fish -c "fisher list" &>/dev/null; then
        substep_success "Installed fisher plugins succesfully!"
    else
        substep_error "Failed to install fisher plugins!"
    fi
    
}

if set_fish_shell; then
    success "Successfully set up fish shell."
else
    error "Failed setting up fish shell."
fi