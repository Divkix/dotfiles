# setup gpg tty
set -gx GPG_TTY (tty)

# eval homebrew
eval (/opt/homebrew/bin/brew shellenv)

set --export BUN_INSTALL "$HOME/.bun" # bun

# Add home bin to PATH
fish_add_path "$HOME/.local/bin"
fish_add_path "$HOME/go/bin" # add go bin to path
fish_add_path "$HOME/.cargo/bin" # add rust bin to path
fish_add_path $BUN_INSTALL/bin # bun
fish_add_path /opt/homebrew/opt/libpq/bin # psql

#----------------------------------#
# homebrew additional config start #
#----------------------------------#

# use nano as default editor
set -gx EDITOR nano

# add curl
fish_add_path "/opt/homebrew/opt/curl/bin"
set -gx LDFLAGS "-L/opt/homebrew/opt/curl/lib"
set -gx CPPFLAGS "-I/opt/homebrew/opt/curl/include"
set -gx PKG_CONFIG_PATH "/opt/homebrew/opt/curl/lib/pkgconfig"

# fzf config
fzf_configure_bindings --directory=\cf
set -g fzf_preview_dir_cmd lsd --all --icon never --color=always
set -g fzf_fd_opts -t f -t l -p -H

# python config
fish_add_path "/opt/homebrew/opt/python/bin"
fish_add_path "/opt/homebrew/opt/python/libexec/bin"
set -gx LDFLAGS "-L/opt/homebrew/opt/python/lib"

# java config -- temurin
set -gx JAVA_HOME $(/usr/libexec/java_home)
fish_add_path "$JAVA_HOME/bin"

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :

# Added by LM Studio CLI (lms)
set -gx PATH $PATH /Users/divkix/.lmstudio/bin
# End of LM Studio CLI section

# claude
alias claude="/Users/divkix/.claude/local/claude"

# starship prompt setup
set -gx STARSHIP_CONFIG "$HOME/.config/starship.toml"
starship init fish | source
