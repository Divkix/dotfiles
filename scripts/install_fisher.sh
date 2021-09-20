#! /usr/bin/env sh

DIR=$(dirname "$0")
cd "$DIR"

. ../scripts/functions.sh

info "Setting up extra stuff..."

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


success "Extras installed!"

info "Setting up virtualfish..."
mkdir -p "$HOME/.virtualenvs"
if fish -c "vf install \
    auto_activation \
    projects \
    environment \
    update_python" &>/dev/null; then
    substep_success "Virtualfish installed!"
else
    substep_error "Virtualfish failed to install!"
fi