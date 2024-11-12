# setup gpg tty
set -gx GPG_TTY (tty)

# eval homebrew
eval (/opt/homebrew/bin/brew shellenv)

# Add home bin to PATH
fish_add_path "$HOME/bin"

#----------------------------------#
# homebrew additional config start #
#----------------------------------#

# use nano as default editor
set -gx EDITOR micro

# add curl
fish_add_path "/opt/homebrew/opt/curl/bin"
set -gx LDFLAGS "-L/opt/homebrew/opt/curl/lib"
set -gx CPPFLAGS "-I/opt/homebrew/opt/curl/include"
set -gx PKG_CONFIG_PATH "/opt/homebrew/opt/curl/lib/pkgconfig"

# add go bin to path
fish_add_path "$HOME/go/bin"

# add rust bin to path
fish_add_path "$HOME/.cargo/bin"

# fzf config
fzf_configure_bindings --directory=\cf
set -g fzf_preview_dir_cmd lsd --all --icon never --color=always
set -g fzf_fd_opts -t f -t l -p -H

# python config
fish_add_path "/opt/homebrew/opt/python/bin"
fish_add_path "/opt/homebrew/opt/python/libexec/bin"
set -gx LDFLAGS "-L/opt/homebrew/opt/python/lib"

#--------------------------------#
# homebrew additional config end #
#--------------------------------#

# starship prompt setup
set -gx STARSHIP_CONFIG "$HOME/.config/starship.toml"
starship init fish | source
