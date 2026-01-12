# setup gpg tty
set -gx GPG_TTY (tty)

# eval homebrew
eval (/opt/homebrew/bin/brew shellenv)

# use nano as default editor
set -gx EDITOR nano

# Add home bin to PATH
fish_add_path "$HOME/.local/bin"
fish_add_path "$HOME/go/bin"
fish_add_path "$HOME/.cargo/bin"
fish_add_path "$HOME/.bun/bin"
fish_add_path "/Users/divkix/.deno/bin"

# add curl
fish_add_path "/opt/homebrew/opt/curl/bin"
set -gx LDFLAGS "-L/opt/homebrew/opt/curl/lib"
set -gx CPPFLAGS "-I/opt/homebrew/opt/curl/include"
set -gx PKG_CONFIG_PATH "/opt/homebrew/opt/curl/lib/pkgconfig"

# add ruby
fish_add_path /opt/homebrew/opt/ruby/bin
set -gx LDFLAGS "-L/opt/homebrew/opt/ruby/lib"
set -gx CPPFLAGS "-I/opt/homebrew/opt/ruby/include"
set -gx PKG_CONFIG_PATH "/opt/homebrew/opt/ruby/lib/pkgconfig"

# fzf config
fzf_configure_bindings --directory=\cf
set -g fzf_preview_dir_cmd lsd --all --icon never --color=always
set -g fzf_fd_opts -t f -t l -p -H

# Added by LM Studio CLI (lms)
set -gx PATH $PATH /Users/divkix/.lmstudio/bin
# End of LM Studio CLI section

# sdkman init
set -gx SDKMAN_DIR (brew --prefix sdkman-cli)/libexec
bass source "$SDKMAN_DIR/bin/sdkman-init.sh"

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :

# starship prompt setup
set -gx STARSHIP_CONFIG "$HOME/.config/starship.toml"
starship init fish | source
