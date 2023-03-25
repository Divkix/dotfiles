# cd commands
abbr -g -a .. cd ..
abbr -g -a ... cd ../..

# ls commands
abbr -g -a l ls
abbr -g -a la ls -a
abbr -g -a ll ls -l

# git commands
abbr -g -a g git
abbr -g -a gcl git clone
abbr -g -a gph git push
abbr -g -a gpl git pull
abbr -g -a gst git status
abbr -g -a gcm git commit -m
abbr -g -a gcam git commit -am
abbr -g -a gco git commit
abbr -g -a gca git commit -a --amend
abbr -g -a gcan git commit --amend -a --no-edit

# others
abbr -g -a reload exec fish
abbr -g -a c "clear && printf '\e[3J'"
abbr -g -a cp cp -i
abbr -g -a df df -h
abbr -g -a free free -m
abbr -g -a ln ln -i
abbr -g -a less more
abbr -g -a mv mv -i
abbr -g -a snano sudo nano
abbr -g -a www python3 -m http.server 8000
abbr -g -a untar tar -zxvf
