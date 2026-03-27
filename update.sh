#!/bin/bash

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

copy_file() {
    local source="$1"
    local destination="$2"

    mkdir -p "$(dirname "$destination")"
    cp -v "$source" "$destination"
}

sync_directory() {
    local source_dir="$1"
    local destination_dir="$2"

    rm -rf "$destination_dir"

    if [ ! -d "$source_dir" ]; then
        return 0
    fi

    mkdir -p "$destination_dir"
    cp -v -R "$source_dir"/. "$destination_dir"/
}

fish_dir="$HOME/.config/fish"
copy_file "$fish_dir/config.fish" "./fish/config.fish"
copy_file "$fish_dir/functions/fish_prompt.fish" "./fish/functions/fish_prompt.fish"
copy_file "$fish_dir/functions/fish_greeting.fish" "./fish/functions/fish_greeting.fish"
copy_file "$fish_dir/functions/fish_prompt_loading_indicator.fish" "./fish/functions/fish_prompt_loading_indicator.fish"
copy_file "$fish_dir/conf.d/abbr.fish" "./fish/conf.d/abbr.fish"
copy_file "$fish_dir/conf.d/alias.fish" "./fish/conf.d/alias.fish"

claude_dir="$HOME/.claude"
copy_file "$claude_dir/settings.json" "./claude/settings.json"
copy_file "$claude_dir/CLAUDE.md" "./claude/CLAUDE.md"
sync_directory "$claude_dir/agents" "./claude/agents"
sync_directory "$claude_dir/commands" "./claude/commands"
copy_file "$HOME/.claude.json" "./claude/claude.json"

opencode_dir="$HOME/.config/opencode"
copy_file "$opencode_dir/opencode.json" "./opencode/opencode.json"
copy_file "$opencode_dir/AGENTS.md" "./opencode/AGENTS.md"
if [ -f "$opencode_dir/dcp.jsonc" ]; then
    copy_file "$opencode_dir/dcp.jsonc" "./opencode/dcp.jsonc"
else
    rm -f "./opencode/dcp.jsonc"
fi
sync_directory "$opencode_dir/prompts" "./opencode/prompts"
rm -rf "./opencode/agent"

ghostty_dir="$HOME/.config/ghostty"
copy_file "$ghostty_dir/config" "./ghostty/config"

fish_plugins="$(fish -c 'fisher list')"
: > "./fisher/fisher install.list"
if [ -n "$fish_plugins" ]; then
    while IFS= read -r plugin; do
        if [ -z "$plugin" ] || [ "$plugin" = "jorgebucaran/fisher" ]; then
            continue
        fi

        printf '%s\n' "$plugin" >> "./fisher/fisher install.list"
    done <<< "$fish_plugins"
fi

copy_file "$HOME/.gitconfig" "./git/.gitconfig"
copy_file "$HOME/.gitignore_global" "./git/.gitignore_global"
copy_file "$HOME/.ssh/config" "./ssh/config"

gnupg_dir="$HOME/.gnupg"
copy_file "$gnupg_dir/gpg.conf" "./gnupg/gpg.conf"
copy_file "$gnupg_dir/gpg-agent.conf" "./gnupg/gpg-agent.conf"

brew bundle dump --force --describe --file=./packages/Brewfile
echo "brew bundle dump complete"

copy_file "$HOME/.config/starship.toml" "./starship/starship.toml"

echo "Update script complete"
