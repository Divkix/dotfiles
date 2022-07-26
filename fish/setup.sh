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

find * -name "*fish*" | while read fn; do
    scopy "$SOURCE/$fn" "$DESTINATION/$fn"
done
clear_broken_symlinks "$DESTINATION"

# after it has been installed by homebrew
fish_shell_location="/opt/homebrew/bin/fish"

set_fish_shell() {
    if echo $SHELL | grep -q "$fish_shell_location"; then
        success "Fish shell is already set up."
    else
        substep_info "Checking if fish is installed..."
        if cat /etc/shells | grep -q "$fish_shell_location"; then
            substep_info "Fish shell already installed"
        else
            substep_error "Fish shell is not installed. Setting it up..."
            sudo sh -c 'echo /opt/homebrew/bin/fish >> /etc/shells'
        fi
        substep_info "Changing shell to fish"
        if sudo chsh -s $fish_shell_location $(whoami); then
            substep_success "Changed shell to fish"
        else
            substep_error "Failed changing shell to fish"
            return 2
        fi
    fi    
}

if set_fish_shell; then
    success "Successfully set up fish shell."
else
    error "Failed setting up fish shell."
fi
