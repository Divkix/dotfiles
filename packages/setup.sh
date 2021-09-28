#! /usr/bin/env sh

DIR=$(dirname "$0")
cd "$DIR"

. ../scripts/functions.sh

COMMENT=\#*

sudo -v

info "Installing Yay packages..."
yay -S --noconfirm --needed - < Yayfile
substep_info "Clearing caches and other misc. stuff"
yay -Yc --noconfirm
yay -Scc --noconfirm
substep_success "Done cleaning!"
success "Finished installing Yay packages."


find * -name "*.list" | while read fn; do
    cmd="${fn%.*}"
    set -- $cmd
    info "Installing $1 packages..."
    while read package; do
        if [[ $package == $COMMENT ]];
        then continue
        fi
        substep_info "Installing $package..."
        if [[ $cmd == code* ]]; then
            $cmd $package
        else
            $cmd install $package $i &>/dev/null
        fi
    done < "$fn"
    substep_success "Finished installing $1 packages."
done
