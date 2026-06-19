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

# add curl
fish_add_path "/opt/homebrew/opt/curl/bin"
set -gx LDFLAGS "-L/opt/homebrew/opt/curl/lib"
set -gx CPPFLAGS "-I/opt/homebrew/opt/curl/include"
set -gx PKG_CONFIG_PATH "/opt/homebrew/opt/curl/lib/pkgconfig"

# add fmpeg
fish_add_path /opt/homebrew/opt/ffmpeg-full/bin
set -gx LDFLAGS "-L/opt/homebrew/opt/ffmpeg-full/lib"
set -gx CPPFLAGS "-I/opt/homebrew/opt/ffmpeg-full/include"
set -gx PKG_CONFIG_PATH "/opt/homebrew/opt/ffmpeg-full/lib/pkgconfig"

# add imagemagick
fish_add_path /opt/homebrew/opt/imagemagick-full/bin
set -gx LDFLAGS "-L/opt/homebrew/opt/imagemagick-full/lib"
set -gx CPPFLAGS "-I/opt/homebrew/opt/imagemagick-full/include"
set -gx PKG_CONFIG_PATH "/opt/homebrew/opt/imagemagick-full/lib/pkgconfig"

# add llvm
fish_add_path /opt/homebrew/opt/llvm/bin

# openssl
set -x LDFLAGS "-L/opt/homebrew/opt/openssl@3/lib"
set -x CPPFLAGS "-I/opt/homebrew/opt/openssl@3/include"
set -x PKG_CONFIG_PATH "/opt/homebrew/opt/openssl@3/lib/pkgconfig"

# fzf config
fzf_configure_bindings --directory=\cf
set -g fzf_preview_dir_cmd lsd --all --icon never --color=always
set -g fzf_fd_opts -t f -t l -p -H

# enable experimental features in opencode
set -gx OPENCODE_EXPERIMENTAL true
set -gx OPENCODE_EXPERIMENTAL_NATIVE_LLM true
set -gx OPENCODE_EXPERIMENTAL_WEBSOCKETS true
set -gx OPENCODE_EXPERIMENTAL_WORKSPACES true

# morphllm
set -gx MORPH_API_KEY ""

# commandcode api key for opencode auth
set -gx COMMANDCODE_API_KEY ""

# Added by LM Studio CLI (lms)
set -gx PATH $PATH /Users/divkix/.lmstudio/bin
# End of LM Studio CLI section

# Disable Telementry
set -gx DO_NOT_TRACK 1
set -gx DO_NOT_TRACK = "1";
set -gx HOMEBREW_NO_ANALYTICS = "1";
set -gx NEXT_TELEMETRY_DISABLED = "1";
set -gx GATSBY_TELEMETRY_DISABLED = "1";
set -gx VSCODE_TELEMETRY_LEVEL = "off";
set -gx DOTNET_CLI_TELEMETRY_OPTOUT = "1";
set -gx POWERSHELL_TELEMETRY_OPTOUT = "1";
set -gx FUNCTIONS_CORE_TOOLS_TELEMETRY_OPTOUT = "1";

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :

# starship prompt setup
set -gx STARSHIP_CONFIG "$HOME/.config/starship.toml"
starship init fish | source
