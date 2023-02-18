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
set -gx EDITOR nano

# add rust bin to path
fish_add_path "$HOME/.cargo/bin"

# fzf config
set -g FZF_CTRL_T_COMMAND "command find -L \$dir -type f 2> /dev/null | sed '1d; s#^\./##'"
fzf_configure_bindings --directory=\co
set -g fzf_preview_dir_cmd exa --all --color=always
set -g fzf_fd_opts -t f -t l -p -H

# python config
fish_add_path "/opt/homebrew/opt/python@3.11/bin"
fish_add_path "/opt/homebrew/opt/python@3.11/libexec/bin"
set -gx LDFLAGS "-L/opt/homebrew/opt/python@3.11/lib"

# jetbrains toolbox custom scripts
fish_add_path "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"

#--------------------------------#
# homebrew additional config end #
#--------------------------------#

# starship prompt setup
set -gx STARSHIP_CONFIG "$HOME/.config/starship.toml"
starship init fish | source
