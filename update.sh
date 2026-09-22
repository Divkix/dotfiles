#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$REPO_ROOT" || exit 1

TMP_DIR="$(mktemp -d "$REPO_ROOT/.update.sh.XXXXXX")"
STAGE_DIR="$TMP_DIR/stage"
BACKUP_DIR="$TMP_DIR/backup"
mkdir -p "$STAGE_DIR" "$BACKUP_DIR"

declare -a MANAGED_TARGETS=()
declare -a APPLIED_TARGETS=()
APPLY_IN_PROGRESS=0

track_target() {
    local relative_target="$1"
    local existing_target

    if [ "${#MANAGED_TARGETS[@]}" -gt 0 ]; then
        for existing_target in "${MANAGED_TARGETS[@]}"; do
            if [ "$existing_target" = "$relative_target" ]; then
                return 0
            fi
        done
    fi

    MANAGED_TARGETS+=("$relative_target")
}

stage_file() {
    local source="$1"
    local relative_target="$2"
    local staged_target="$STAGE_DIR/$relative_target"

    track_target "$relative_target"

    if [ ! -e "$source" ] && [ ! -h "$source" ]; then
        return 0
    fi

    mkdir -p "$(dirname "$staged_target")"
    cp -P -v "$source" "$staged_target"
}

generate_fisher_manifest() {
    local staged_target="$STAGE_DIR/fisher/fisher install.list"
    local fish_plugins=""
    local plugin

    track_target "fisher/fisher install.list"
    mkdir -p "$(dirname "$staged_target")"
    : > "$staged_target"

    if ! fish_plugins="$(fish -c 'fisher list')"; then
        return 1
    fi

    if [ -z "$fish_plugins" ]; then
        return 0
    fi

    while IFS= read -r plugin; do
        if [ -z "$plugin" ] || [ "$plugin" = "jorgebucaran/fisher" ]; then
            continue
        fi

        printf '%s\n' "$plugin" >> "$staged_target"
    done <<< "$fish_plugins"
}

generate_brewfile() {
    local staged_target="$STAGE_DIR/packages/Brewfile"
    local brew_dir

    track_target "packages/Brewfile"
    mkdir -p "$(dirname "$staged_target")"
    # No --describe: descriptions are the default since Homebrew 7; the flag is
    # odisabled and errors out. Use --no-describe / HOMEBREW_BUNDLE_NO_DESCRIBE to opt out.
    # Homebrew's bin dir goes first because brew detects global npm packages through PATH:
    # with a node runtime shim ahead of it (e.g. ~/.vite-plus/bin) the dump reports that
    # runtime's bundled npm/corepack instead of the real global packages.
    brew_dir="$(dirname "$(command -v brew)")"
    if ! PATH="$brew_dir:$PATH" brew bundle dump --force --file="$staged_target"; then
        return 1
    fi
    [ -f "$staged_target" ]
}

stage_fish_config() {
    local source="$1"
    local staged_target="$STAGE_DIR/fish/config.fish"

    track_target "fish/config.fish"

    if [ ! -f "$source" ]; then
        return 0
    fi

    mkdir -p "$(dirname "$staged_target")"
    # Blank secret-bearing `set -gx NAME "..."` exports (API keys, tokens, secrets,
    # passwords) so they never reach this public repo. Matches on the variable name
    # only; non-secret exports (PATH, SSH_AUTH_SOCK, DO_NOT_TRACK, ...) pass through.
    if ! awk '
        $1 == "set" && $2 == "-gx" && $3 ~ /(_KEY|_TOKEN|_SECRET|_PASSWORD|_PASSWD|APIKEY)$/ {
            print "set -gx " $3 " \"\""
            next
        }
        { print }
    ' "$source" > "$staged_target"; then
        return 1
    fi
}

# Stage the OMP agent global config (~/.omp/agent/config.yml). Provider credentials
# normally live elsewhere (the agent.db auth store, environment variables, models.yml),
# but config.yml has documented secret fields (searxng.token, searxng.basicPassword,
# auth.broker.token), so secret-bearing values are blanked on capture.
stage_omp_config() {
    local source="$HOME/.omp/agent/config.yml"
    local staged_target="$STAGE_DIR/omp/config.yml"

    track_target "omp/config.yml"

    if [ ! -f "$source" ]; then
        return 0
    fi

    mkdir -p "$(dirname "$staged_target")"
    # Blank the inline scalar value of any `key: value` line whose key name looks
    # secret-bearing (API keys, tokens, secrets, passwords, credentials, private keys),
    # including nested/dotted leaves such as `searxng.token`. Boolean and numeric values
    # are left alone so a matched non-secret key keeps its type and the file stays
    # schema-valid. Nested blocks under a secret-named key and quoted keys are not
    # scrubbed.
    if ! awk '
        {
            line = $0
            if (line ~ /^[[:space:]]*[A-Za-z0-9_.-]+[[:space:]]*:/) {
                key = line
                sub(/[[:space:]]*:.*$/, "", key)
                sub(/^[[:space:]]+/, "", key)
                value = line
                sub(/^[^:]*:[[:space:]]*/, "", value)
                if (value != "" &&
                    tolower(key) ~ /(api[_-]?key|access[_-]?key|secret|password|passwd|passphrase|(auth|access|refresh|id)[_-]?token|bearer|authorization|credential|private[_-]?key|(^|[._-])(key|token|secret)([._-]|$))/ &&
                    tolower(value) !~ /^(true|false|null|~|yes|no|on|off)$/ &&
                    value !~ /^-?[0-9]+([.][0-9]+)?$/) {
                    sub(/[[:space:]]*:.*$/, "", line)
                    line = line ": \"\""
                }
            }
            print line
        }
    ' "$source" > "$staged_target"; then
        return 1
    fi
}

stage_zed_settings() {
    local source="$HOME/.config/zed/settings.json"
    local staged_target="$STAGE_DIR/zed/settings.json"
    local ext_dir="$HOME/Library/Application Support/Zed/extensions/installed"
    local entries

    track_target "zed/settings.json"

    if [ ! -f "$source" ]; then
        return 0
    fi

    mkdir -p "$(dirname "$staged_target")"

    # No installed-extensions dir -> capture settings.json verbatim.
    if [ ! -d "$ext_dir" ]; then
        cp -P "$source" "$staged_target"
        return 0
    fi

    # Build "<id>": true lines from installed extension folder names. The folder name
    # is the extension ID; this is the source of truth for what is installed.
    entries="$(find "$ext_dir" -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort | while IFS= read -r p; do
        printf '    "%s": true,\n' "${p##*/}"
    done)"

    # Regenerate ONLY the auto_install_extensions block while preserving the rest of the
    # JSONC (comments, key order, trailing commas). Matches the canonical multi-line form
    # `  "auto_install_extensions": {` ... `  },`; any other shape is copied through
    # untouched because the open-brace anchor never matches it. Entries are passed via the
    # environment (ENVIRON) because awk -v cannot carry the embedded newlines.
    if ! ZED_EXT_ENTRIES="$entries" awk '
        /^  "auto_install_extensions": \{$/ { print; if (ENVIRON["ZED_EXT_ENTRIES"] != "") print ENVIRON["ZED_EXT_ENTRIES"]; skip=1; next }
        skip && /^  \},?[[:space:]]*$/      { print; skip=0; next }
        skip { next }
        { print }
    ' "$source" > "$staged_target"; then
        return 1
    fi
}

# The repo's pre-commit hook strips trailing whitespace, so normalize the captured copy
# too: a live config with trailing spaces (e.g. the `helper = ` line `gh auth setup-git`
# writes into ~/.gitconfig) would otherwise be re-captured dirty on every run. Symlinks
# are skipped so link snapshots keep pointing at their target.
strip_staged_trailing_whitespace() {
    local staged_file
    local temp_file="$TMP_DIR/strip.tmp"

    while IFS= read -r staged_file; do
        if ! awk '{ sub(/[[:space:]]+$/, ""); print }' "$staged_file" > "$temp_file"; then
            return 1
        fi

        if ! mv "$temp_file" "$staged_file"; then
            return 1
        fi
    done < <(find "$STAGE_DIR" -type f)
}

restore_backups() {
    local index
    local relative_target
    local target_path
    local backup_path
    local rollback_failed=0

    for ((index=${#APPLIED_TARGETS[@]} - 1; index>=0; index--)); do
        relative_target="${APPLIED_TARGETS[$index]}"
        target_path="$REPO_ROOT/$relative_target"
        backup_path="$BACKUP_DIR/$relative_target"

        if ! rm -rf "$target_path"; then
            printf 'Rollback failed: could not remove %s\n' "$target_path" >&2
            rollback_failed=1
            continue
        fi

        if [ -e "$backup_path" ] || [ -h "$backup_path" ]; then
            if ! mkdir -p "$(dirname "$target_path")"; then
                printf 'Rollback failed: could not recreate parent for %s\n' "$target_path" >&2
                rollback_failed=1
                continue
            fi

            if ! mv "$backup_path" "$target_path"; then
                printf 'Rollback failed: could not restore %s\n' "$relative_target" >&2
                rollback_failed=1
            fi
        fi
    done

    return "$rollback_failed"
}

apply_target() {
    local relative_target="$1"
    local target_path="$REPO_ROOT/$relative_target"
    local staged_target="$STAGE_DIR/$relative_target"
    local backup_path="$BACKUP_DIR/$relative_target"

    mkdir -p "$(dirname "$backup_path")"

    if [ -e "$target_path" ] || [ -h "$target_path" ]; then
        mv "$target_path" "$backup_path"
    fi

    APPLIED_TARGETS+=("$relative_target")

    if [ -e "$staged_target" ] || [ -h "$staged_target" ]; then
        mkdir -p "$(dirname "$target_path")"
        mv "$staged_target" "$target_path"
    fi
}

apply_staged_targets() {
    local relative_target

    APPLY_IN_PROGRESS=1

    for relative_target in "${MANAGED_TARGETS[@]}"; do
        apply_target "$relative_target"
    done

    APPLY_IN_PROGRESS=0
}

cleanup() {
    local exit_code="$1"

    trap - EXIT

    if [ "$exit_code" -ne 0 ] && [ "$APPLY_IN_PROGRESS" -eq 1 ]; then
        if ! restore_backups; then
            printf 'Rollback failed; repo may be partially updated\n' >&2
            printf 'Rollback artifacts kept at %s\n' "$TMP_DIR" >&2
            exit "$exit_code"
        fi
    fi

    rm -rf "$TMP_DIR"
    exit "$exit_code"
}

trap 'cleanup "$?"' EXIT

fish_dir="$HOME/.config/fish"
stage_fish_config "$fish_dir/config.fish"
stage_file "$fish_dir/functions/fish_prompt.fish" "fish/functions/fish_prompt.fish"
stage_file "$fish_dir/functions/fish_greeting.fish" "fish/functions/fish_greeting.fish"
stage_file "$fish_dir/functions/fish_prompt_loading_indicator.fish" "fish/functions/fish_prompt_loading_indicator.fish"
stage_file "$fish_dir/conf.d/abbr.fish" "fish/conf.d/abbr.fish"
stage_file "$fish_dir/conf.d/alias.fish" "fish/conf.d/alias.fish"

stage_file "$HOME/.config/ghostty/config" "ghostty/config"

stage_zed_settings
stage_file "$HOME/.config/zed/keymap.json" "zed/keymap.json"

stage_omp_config

generate_fisher_manifest

stage_file "$HOME/.gitconfig" "git/.gitconfig"
stage_file "$HOME/.gitignore_global" "git/.gitignore_global"
stage_file "$HOME/.ssh/config" "ssh/config"

gnupg_dir="$HOME/.gnupg"
stage_file "$gnupg_dir/gpg.conf" "gnupg/gpg.conf"
stage_file "$gnupg_dir/gpg-agent.conf" "gnupg/gpg-agent.conf"

generate_brewfile
echo "brew bundle dump complete"

stage_file "$HOME/.config/starship.toml" "starship/starship.toml"

strip_staged_trailing_whitespace

apply_staged_targets

echo "Update script complete"
