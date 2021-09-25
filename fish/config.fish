
#### ---- HomeBrew Stuff first ---- ####
# eval homebrew first
eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv)

# Add python3 unversioned symlinks to path
set -gx PATH "/home/linuxbrew/.linuxbrew/opt/python@3.9/libexec/bin" $PATH

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
    set -gx PATH "/mnt/c/Users/$WINDOWS_USER_NAME/AppData/Local/Programs/Microsoft VS Code/bin" $PATH

end

# add yarn global bin
set -gx PATH (yarn global bin) $PATH

# init golang
set -x GOPATH $HOME/go
set -x PATH $PATH $GOPATH/bin

# set starship config
set -gx STARSHIP_CONFIG $HOME/.config/starship.toml

# start starship prompt
starship init fish | source
