# setup gpg tty
set -gx GPG_TTY (tty)

# eval homebrew
eval (/opt/homebrew/bin/brew shellenv)

# Add home bin to PATH
fish_add_path $HOME/bin

# Add Deno bin to PATH
fish_add_path $HOME/.deno/bin

#----------------------------#
# homebrew additional config #
#----------------------------#

# fzf config
set -g FZF_CTRL_T_COMMAND "command find -L \$dir -type f 2> /dev/null | sed '1d; s#^\./##'"
fzf_configure_bindings --directory=\co
set -g fzf_preview_dir_cmd exa --all --color=always
set -g fzf_fd_opts -t f -t l -p -H

fish_add_path /opt/homebrew/opt/python@3.10/bin
fish_add_path /opt/homebrew/opt/openjdk/bin
set -gx LDFLAGS "-L/opt/homebrew/opt/python@3.10/lib"

#----------------------------#
# homebrew additional config #
#----------------------------#

# set starship config
set -gx STARSHIP_CONFIG $HOME/.config/starship.toml

# start starship prompt
starship init fish | source
