# setup gpg tty
set -gx GPG_TTY (tty)

# check if distribution is WSL or not
# if yes, then add some things to PATH
if string match -r -i -q "^(.+)-microsoft-standard-WSL2" -- (uname -r)

    # Get windows user directory        
    set WINDOWS_USER_NAME (string split -f2 -r -m1 \\ (/mnt/c/Windows/System32/cmd.exe /c echo %USERPROFILE% | string trim -c \r))

    # clean mess made by cmd
    clear

    # add vscode to path
    set -gx PATH "/mnt/c/Users/$WINDOWS_USER_NAME/scoop/apps/vscode/current/bin/" $PATH

end

# Add local bin to path
set -gx PATH "$HOME/.local/bin" $PATH

# set starship config
set -gx STARSHIP_CONFIG $HOME/.config/starship.toml

# start starship prompt
starship init fish | source
