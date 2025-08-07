#!/bin/bash

# bash script to update the files here
# this script is run from the root of the repo

# update the fish config
fish_dir=$HOME/.config/fish
cp -v $fish_dir/config.fish ./fish/config.fish
cp -v $fish_dir/functions/fish_prompt.fish ./fish/functions/fish_prompt.fish
cp -v $fish_dir/functions/fish_greeting.fish ./fish/functions/fish_greeting.fish
cp -v $fish_dir/functions/fish_prompt_loading_indicator.fish ./fish/functions/fish_prompt_loading_indicator.fish
cp -v $fish_dir/conf.d/abbr.fish ./fish/conf.d/abbr.fish
cp -v $fish_dir/conf.d/alias.fish ./fish/conf.d/alias.fish

# copy .claude dir
claude_dir=$HOME/.claude
cp -v -r $claude_dir/settings.json ./claude/settings.json
cp -v $claude_dir/CLAUDE.md ./claude/CLAUDE.md
cp -v -r $claude_dir/agents/* ./claude/agents/
cp -v -r $claude_dir/commands/* ./claude/commands/
cp -v $HOME/.claude.json ./claude/claude.json

# opencode
opencode_dir=$HOME/.config/opencode
cp -v -r $opencode_dir/* ./opencode

# copy ghostty config
ghostty_dir=$HOME/.config/ghostty
cp -v $ghostty_dir/config ./ghostty/config

# update fisher, using fish -c to run the command from fish shell instead of bash
fish -c "fisher list | grep -v "jorgebucaran/fisher" > './fisher/fisher install.list'"

# update git config
cp -v $HOME/.gitconfig ./git/.gitconfig
cp -v $HOME/.gitignore_global ./git/.gitignore_global

# copy ssh config
cp -v $HOME/.ssh/config ./ssh/config

# gnupg config
gnupg_dir=$HOME/.gnupg
cp -v $gnupg_dir/gpg.conf ./gnupg/gpg.conf
cp -v $gnupg_dir/gpg-agent.conf ./gnupg/gpg-agent.conf

# packages
# dump new brewfile
brew bundle dump --force --describe --file=./packages/Brewfile
echo "brew bundle dump complete"

# starship
cp -v $HOME/.config/starship.toml ./starship/starship.toml

# Echo that the script is done
echo "Update script complete"
