#! /usr/bin/env sh

DIR=$(dirname "$0")
cd "$DIR"

. ../scripts/functions.sh

info "Installing some pre-requisites..."

substep_info "Installing Yay Package Manager..."
if yay --version &>/dev/null; then
    substep_success "Yay already installed."
elif sudo pacman -S yay --noconfirm &>/dev/null; then
    substep_success "Finished installing Yay package manager."
else
    substep_error "Failed to install Yay package manager."
fi

reqPackages=("base-devel")

for i in "${reqPackages[@]}"; do
  substep_info "Installing $i..."
    if yay -Qs $i &>/dev/null; then
        substep_success "$i already installed."
    elif yay -S --noconfirm &>/dev/null; then
        substep_success "Finished installing $i."
    else
        substep_error "Failed to install $i."
    fi
done

success "Finished installing pre-requisites."
