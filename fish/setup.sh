#! /usr/bin/env sh

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

find * -name "*fish*" -not -wholename "fish_plugins" | while read fn; do
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
}

if set_fish_shell; then
    success "Successfully set up fish shell."
    substep_info "Setting up Fisher..."
    if fish -c "fisher -v"; then
        substep_success "Fisher already installed!"
        scopy "$SOURCE/fish_plugins" "$DESTINATION/fish_plugins"
        fish -c "fisher update"
    else
        substep_info "Fisher not installed."
        exit 1
    fi
else
    error "Failed setting up fish shell."
fi