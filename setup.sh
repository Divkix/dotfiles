#!/bin/bash
# setup.sh — the only entry point.
#   ./setup.sh                        restore: install packages + apply repo config here
#   ./setup.sh update                 capture live config back into the repo
#   ./setup.sh restore|update <mod…>  run one direction for selected modules only

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
R="$PWD"

step() { printf '\n=== %s ===\n' "$*"; }
warn() { printf '!! %s\n' "$*" >&2; }

MODULES=(packages fish fisher git ssh gnupg starship ghostty zed omp claude codex
    skills herdr worktrunk btop gh agent-browser playwright macos)

FISH_FILES=(
    config.fish
    conf.d/abbr.fish
    conf.d/alias.fish
    functions/fish_greeting.fish
    functions/fish_prompt.fish
    functions/fish_prompt_loading_indicator.fish
    functions/goup.fish
)

# ---------------------------------------------------------------------------
# restore helpers
# ---------------------------------------------------------------------------

# Copy one file to its live location, creating parents; falls back to sudo for
# root-owned destinations and hands ownership back to the user afterwards.
put_file() {
    local src="$1" dst="$2" label="${3:-$1}"
    if [ ! -e "$src" ] && [ ! -L "$src" ]; then
        warn "missing $label"
        return 1
    fi
    mkdir -p "$(dirname "$dst")" 2>/dev/null || sudo mkdir -p "$(dirname "$dst")"
    if ! cp -f "$src" "$dst" 2>/dev/null; then
        sudo cp -f "$src" "$dst" || {
            warn "failed copying $label -> $dst"
            return 1
        }
        sudo chown "$(id -u):$(id -g)" "$dst" || true
    fi
    printf '  %s -> %s\n' "$label" "$dst"
}

put() { put_file "$R/$1" "$2" "$1"; }

# put with __HOME__ in the repo file swapped for the real home directory.
put_home() {
    local tmp rc=0
    tmp="$(mktemp)"
    if ! sed "s#__HOME__#$HOME#g" "$R/$1" >"$tmp"; then
        rm -f "$tmp"
        warn "rendering $1"
        return 1
    fi
    put_file "$tmp" "$2" "$1" || rc=$?
    rm -f "$tmp"
    return "$rc"
}

# chmod that tolerates the file being owned by root (after a sudo put).
perm() { chmod "$1" "$2" 2>/dev/null || sudo chmod "$1" "$2"; }

SUDO_PID=""
sudo_keepalive() {
    sudo -v || {
        warn "sudo credentials required."
        exit 1
    }
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done >/dev/null 2>&1 </dev/null &
    SUDO_PID=$!
}

stop_keepalive() {
    if [ -n "$SUDO_PID" ]; then
        kill "$SUDO_PID" 2>/dev/null || true
        wait "$SUDO_PID" 2>/dev/null || true
        SUDO_PID=""
    fi
    return 0
}

# ---------------------------------------------------------------------------
# update helpers
# ---------------------------------------------------------------------------

CAPTURED=()

# Copy a live file into the repo. An optional filter command rewrites it on the
# way (the live path is appended as the filter's last argument). A missing live
# file prunes the repo snapshot on purpose, same as the old update.sh.
take() {
    local src="$1" rpath="$2" dst
    shift 2
    dst="$R/$rpath"
    if [ ! -e "$src" ] && [ ! -L "$src" ]; then
        if [ -e "$dst" ]; then
            rm -f "$dst"
            printf '  pruned %s (live file missing)\n' "$rpath"
        fi
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    if [ "$#" -eq 0 ]; then
        cp -Pf "$src" "$dst"
    elif ! "$@" "$src" >"$dst.tmp"; then
        rm -f "$dst.tmp"
        warn "filter failed on $src"
        return 1
    else
        mv "$dst.tmp" "$dst"
    fi
    CAPTURED+=("$rpath")
    printf '  %s -> %s\n' "$src" "$rpath"
}

# The pre-commit hook strips trailing whitespace, so captured files must be
# stripped too or a dirty live file would re-capture dirty every run.
strip_trailing_ws() {
    local f
    for f in ${CAPTURED[@]+"${CAPTURED[@]}"}; do
        f="$R/$f"
        [ -f "$f" ] && [ ! -L "$f" ] || continue
        sed 's/[[:space:]]*$//' "$f" >"$f.tmp" && mv "$f.tmp" "$f"
    done
}

# --- capture filters -------------------------------------------------------

# Blank `set -gx NAME "..."` exports whose name looks secret-bearing so API keys
# never reach this public repo; other exports pass through.
_blank_fish_secrets() {
    awk '
        $1 == "set" && $2 == "-gx" && $3 ~ /(_KEY|_TOKEN|_SECRET|_PASSWORD|_PASSWD|APIKEY)$/ {
            print "set -gx " $3 " \"\""; next
        }
        { print }' "$1"
}

# Blank the inline value of any `key: value` line whose key looks secret-bearing.
# Booleans/numbers are left alone so a matched non-secret key keeps its type.
_blank_yaml_secrets() {
    awk '
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
        }' "$1"
}

_subhome() { sed "s#$HOME#__HOME__#g" "$1"; }

# Drop codex's per-machine sections (trusted projects, hook trust hash,
# model-picker counters); blank lines are re-emitted only before kept content.
_codex_filter() {
    awk '
        /^\[/ { skip = ($0 ~ /^\[(projects|hooks\.state|tui\.model_availability_nux)[].]/) }
        skip { next }
        /^$/ { blank = 1; next }
        { if (n++ && (blank || /^\[/)) print ""; blank = 0; print }' "$1"
}

_skills_manifest() {
    jq -r '
        "# agents: \(.lastSelectedAgents | join(" "))",
        (.skills | to_entries | group_by(.value.source)[]
            | "\(.[0].value.source) \(map(.key) | sort | join(" "))")
    ' "$1"
}

# ---------------------------------------------------------------------------
# modules — restore_* applies repo -> machine, update_* captures machine -> repo
# ---------------------------------------------------------------------------

# Install Homebrew on a fresh machine when the restore includes packages.
ensure_brew() {
    if command -v brew >/dev/null 2>&1; then return 0; fi
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        return 0
    fi
    step "installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        warn "failed installing Homebrew."
        exit 1
    }
    eval "$(/opt/homebrew/bin/brew shellenv)"
}

restore_packages() {
    brew bundle --file=packages/Brewfile
    # App Store apps are separate: `brew bundle` fails wholesale when the Mac is
    # not signed in to the App Store; that warns, it must not abort the restore.
    if [ -f packages/Brewfile.appstore ]; then
        brew bundle --file=packages/Brewfile.appstore ||
            warn "some App Store apps failed; sign in and re-run: ./setup.sh restore packages"
    fi
}

update_packages() {
    local full
    full="$(mktemp)"
    # Homebrew's bin dir goes first in PATH: brew detects global npm packages through
    # PATH and a node shim ahead of it would dump the shim's bundled runtime instead.
    PATH="$(dirname "$(command -v brew)"):$PATH" brew bundle dump --force --file="$full"
    awk '!/^mas /' "$full" >packages/Brewfile
    if command -v mas >/dev/null 2>&1; then
        # appstore.skip lists mas ids that are installed here but not restored elsewhere.
        awk -v skip=packages/appstore.skip '
            BEGIN {
                while ((getline entry < skip) > 0) {
                    sub(/#.*/, "", entry); gsub(/[[:space:]]/, "", entry)
                    if (entry != "") skipped[entry] = 1
                }
            }
            /^mas / && !($NF in skipped)
        ' "$full" >packages/Brewfile.appstore
    else
        warn "mas not installed; leaving packages/Brewfile.appstore untouched"
    fi
    rm -f "$full"
    CAPTURED+=(packages/Brewfile packages/Brewfile.appstore)
}

restore_fish() {
    local f fish_bin
    for f in "${FISH_FILES[@]}"; do
        put "fish/$f" "$HOME/.config/fish/$f"
    done
    mkdir -p "$HOME/.config/fish/completions"

    fish_bin="$(command -v fish)" || {
        warn "fish not installed; run ./setup.sh restore packages first."
        return 1
    }
    if [ "$SHELL" = "$fish_bin" ]; then return 0; fi
    grep -qx "$fish_bin" /etc/shells || echo "$fish_bin" | sudo tee -a /etc/shells >/dev/null
    if ! sudo chsh -s "$fish_bin" "$(whoami)"; then
        warn "failed changing login shell to fish."
        return 1
    fi
    printf '  login shell -> %s\n' "$fish_bin"
}

update_fish() {
    local f
    take "$HOME/.config/fish/config.fish" fish/config.fish _blank_fish_secrets
    for f in "${FISH_FILES[@]:1}"; do
        take "$HOME/.config/fish/$f" "fish/$f"
    done
}

FISHER_LIST="fisher/plugins.list"

restore_fisher() {
    fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher" || {
        warn "failed to bootstrap fisher."
        return 1
    }
    local p
    while IFS= read -r p || [ -n "$p" ]; do
        case "$p" in "" | \#*) continue ;; esac
        fish -c "fisher install $p" </dev/null || {
            warn "failed installing $p"
            return 1
        }
    done <"$FISHER_LIST"
}

update_fisher() {
    # `fisher list` includes fisher itself. An empty list still truncates the manifest.
    fish -c 'fisher list' | { grep -vx 'jorgebucaran/fisher' || true; } >"$FISHER_LIST"
    CAPTURED+=("$FISHER_LIST")
}

restore_git() {
    put git/.gitconfig "$HOME/.gitconfig"
    put git/.gitignore_global "$HOME/.gitignore_global"
}

update_git() {
    take "$HOME/.gitconfig" git/.gitconfig
    take "$HOME/.gitignore_global" git/.gitignore_global
}

restore_ssh() {
    put ssh/config "$HOME/.ssh/config"
    perm 700 "$HOME/.ssh"
    perm 600 "$HOME/.ssh/config"
}

update_ssh() { take "$HOME/.ssh/config" ssh/config; }

restore_gnupg() {
    put gnupg/gpg.conf "$HOME/.gnupg/gpg.conf"
    put gnupg/gpg-agent.conf "$HOME/.gnupg/gpg-agent.conf"
    perm 700 "$HOME/.gnupg"
    perm 600 "$HOME/.gnupg/gpg.conf"
    perm 600 "$HOME/.gnupg/gpg-agent.conf"
}

update_gnupg() {
    take "$HOME/.gnupg/gpg.conf" gnupg/gpg.conf
    take "$HOME/.gnupg/gpg-agent.conf" gnupg/gpg-agent.conf
}

restore_starship() { put starship/starship.toml "$HOME/.config/starship.toml"; }
update_starship() { take "$HOME/.config/starship.toml" starship/starship.toml; }

restore_ghostty() {
    put ghostty/config "$HOME/.config/ghostty/config"
    if command -v duti >/dev/null 2>&1; then
        duti -s com.mitchellh.ghostty public.unix-executable all ||
            warn "duti failed to set Ghostty as the default terminal."
    fi
}

update_ghostty() { take "$HOME/.config/ghostty/config" ghostty/config; }

restore_zed() {
    put zed/settings.json "$HOME/.config/zed/settings.json"
    put zed/keymap.json "$HOME/.config/zed/keymap.json"
}

update_zed() {
    local src="$HOME/.config/zed/settings.json"
    local ext_dir="$HOME/Library/Application Support/Zed/extensions/installed"
    local entries

    if [ ! -f "$src" ]; then
        rm -f zed/settings.json
    elif [ ! -d "$ext_dir" ]; then
        take "$src" zed/settings.json
    else
        # Rebuild ONLY the auto_install_extensions block from the installed extension
        # dirs (folder name = extension ID); the rest of the JSONC passes through.
        entries="$(find "$ext_dir" -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort |
            while IFS= read -r p; do printf '    "%s": true,\n' "${p##*/}"; done)"
        ZED_EXT_ENTRIES="$entries" awk '
            /^  "auto_install_extensions": \{$/ { print; if (ENVIRON["ZED_EXT_ENTRIES"] != "") print ENVIRON["ZED_EXT_ENTRIES"]; skip=1; next }
            skip && /^  \},?[[:space:]]*$/      { print; skip=0; next }
            skip { next }
            { print }
        ' "$src" >zed/settings.json
        CAPTURED+=(zed/settings.json)
    fi
    take "$HOME/.config/zed/keymap.json" zed/keymap.json
}

restore_omp() {
    put omp/config.yml "$HOME/.omp/agent/config.yml"
    put omp/AGENTS.md "$HOME/.omp/agent/AGENTS.md"
}

update_omp() {
    take "$HOME/.omp/agent/config.yml" omp/config.yml _blank_yaml_secrets
    take "$HOME/.omp/agent/AGENTS.md" omp/AGENTS.md
}

restore_claude() {
    mkdir -p "$HOME/.claude"
    put_home claude/settings.json "$HOME/.claude/settings.json"
    # CLAUDE.md links to the shared OMP rules so both agents read one file; a real
    # file already at that path is kept as CLAUDE.md.bak rather than overwritten.
    if [ -e "$HOME/.claude/CLAUDE.md" ] && [ ! -L "$HOME/.claude/CLAUDE.md" ]; then
        mv "$HOME/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md.bak"
    fi
    ln -sfn "$HOME/.omp/agent/AGENTS.md" "$HOME/.claude/CLAUDE.md"
}

update_claude() { take "$HOME/.claude/settings.json" claude/settings.json _subhome; }

restore_codex() {
    put codex/config.toml "$HOME/.codex/config.toml"
    put_home codex/hooks.json "$HOME/.codex/hooks.json"
}

update_codex() {
    take "$HOME/.codex/config.toml" codex/config.toml _codex_filter
    take "$HOME/.codex/hooks.json" codex/hooks.json _subhome
}

restore_skills() {
    local line agents="" failed=0
    local -a fields
    # Manifest: "# agents: <agent> ..." once, then "<source> <skill> [<skill> ...]".
    # Failures warn without aborting: installs need the network.
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            "# agents: "*)
                agents="${line#\# agents: }"
                continue
                ;;
            "" | \#*) continue ;;
        esac
        read -r -a fields <<<"$line"
        # stdin is /dev/null so pnpm cannot swallow the rest of the manifest.
        # shellcheck disable=SC2086 # $agents is a space-separated agent list
        pnpm dlx skills add "${fields[0]}" -g -y -s "${fields[@]:1}" ${agents:+-a $agents} </dev/null ||
            { warn "failed installing skills from ${fields[0]}"; failed=$((failed + 1)); }
    done <skills/skills.list
    if [ "$failed" -gt 0 ]; then warn "$failed skill source(s) failed; re-run ./setup.sh restore skills."; fi
}

update_skills() { take "$HOME/.agents/.skill-lock.json" skills/skills.list _skills_manifest; }

restore_herdr() {
    put herdr/config.toml "$HOME/.config/herdr/config.toml"
    put herdr/close-worktree.sh "$HOME/.config/herdr/close-worktree.sh"
    perm 755 "$HOME/.config/herdr/close-worktree.sh"

    if ! command -v herdr >/dev/null 2>&1; then
        warn "herdr not found; skipping plugin installs."
        return 0
    fi
    local plugin failed=0
    while IFS= read -r plugin || [ -n "$plugin" ]; do
        case "$plugin" in "" | \#*) continue ;; esac
        herdr plugin install -y "$plugin" </dev/null ||
            { warn "failed installing plugin $plugin"; failed=$((failed + 1)); }
    done <herdr/plugins.list
    if [ "$failed" -gt 0 ]; then warn "$failed herdr plugin(s) failed; re-run ./setup.sh restore herdr."; fi
}

update_herdr() {
    take "$HOME/.config/herdr/config.toml" herdr/config.toml
    take "$HOME/.config/herdr/close-worktree.sh" herdr/close-worktree.sh
    if ! command -v herdr >/dev/null 2>&1; then
        warn "herdr not installed; leaving herdr/plugins.list untouched."
        return 0
    fi
    # Only GitHub-sourced plugins are captured; locally linked ones have no repo.
    herdr plugin list --json </dev/null | jq -r '
        .result.plugins[] | select(.source.kind == "github")
        | "\(.source.owner)/\(.source.repo)\(if .source.subdir then "/" + .source.subdir else "" end)"
    ' | LC_ALL=C sort >herdr/plugins.list
    CAPTURED+=(herdr/plugins.list)
}

restore_worktrunk() { put worktrunk/config.toml "$HOME/.config/worktrunk/config.toml"; }
update_worktrunk() { take "$HOME/.config/worktrunk/config.toml" worktrunk/config.toml; }

restore_btop() { put btop/btop.conf "$HOME/.config/btop/btop.conf"; }
update_btop() { take "$HOME/.config/btop/btop.conf" btop/btop.conf; }

restore_gh() { put gh/config.yml "$HOME/.config/gh/config.yml"; }
update_gh() { take "$HOME/.config/gh/config.yml" gh/config.yml; }

restore_agent_browser() { put agent-browser/config.json "$HOME/.agent-browser/config.json"; }
update_agent_browser() { take "$HOME/.agent-browser/config.json" agent-browser/config.json; }

restore_playwright() { put playwright/cli.config.json "$HOME/.playwright/cli.config.json"; }
update_playwright() { take "$HOME/.playwright/cli.config.json" playwright/cli.config.json; }

restore_macos() {
    if ! command -v defaults >/dev/null 2>&1; then
        warn "defaults not available; skipping macOS settings."
        return 0
    fi
    local domain key type value flag failed=0
    # Manifest lines are tab-separated "<domain> <key> <type> <value>". Failures warn
    # without aborting: some domains need extra privacy grants.
    while IFS=$'\t' read -r domain key type value || [ -n "$domain" ]; do
        case "$domain" in "" | \#*) continue ;; esac
        case "$type" in
            boolean)
                if [ "$value" = "1" ]; then value=true; else value=false; fi
                flag="-bool"
                ;;
            integer) flag="-int" ;;
            float) flag="-float" ;;
            string) flag="-string" ;;
            *)
                warn "unsupported type '$type' for $domain $key; skipping."
                failed=$((failed + 1))
                continue
                ;;
        esac
        defaults write "$domain" "$key" "$flag" "$value" </dev/null ||
            { warn "failed writing $domain $key"; failed=$((failed + 1)); }
    done <macos/defaults.list

    # Dock, Finder and the menu bar only re-read preferences on restart.
    for app in Dock Finder SystemUIServer; do
        killall "$app" >/dev/null 2>&1 || true
    done
    if [ "$failed" -gt 0 ]; then
        warn "$failed setting(s) failed; re-run ./setup.sh restore macos. Some keys need a log out and back in."
    fi
}

update_macos() {
    if ! command -v defaults >/dev/null 2>&1; then
        warn "defaults not available; leaving macos/defaults.list untouched."
        return 0
    fi
    local domain key type value
    : >macos/defaults.list
    while read -r domain key || [ -n "$domain" ]; do
        case "$domain" in "" | \#*) continue ;; esac
        type="$(defaults read-type "$domain" "$key" 2>/dev/null </dev/null)" || continue
        type="${type#Type is }"
        case "$type" in boolean | integer | float | string) ;; *) continue ;; esac
        value="$(defaults read "$domain" "$key" 2>/dev/null </dev/null)" || continue
        printf '%s\t%s\t%s\t%s\n' "$domain" "$key" "$type" "$value" >>macos/defaults.list
    done <macos/keys.list
    CAPTURED+=(macos/defaults.list)
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

main() {
    local action=restore
    case "${1:-}" in
        restore | update)
            action="$1"
            shift
            ;;
        -h | --help)
            printf 'usage: %s [restore|update] [module ...]\nmodules: %s\n' "$0" "${MODULES[*]}"
            exit 0
            ;;
    esac

    local mods=("$@")
    if [ "${#mods[@]}" -eq 0 ]; then
        mods=("${MODULES[@]}")
    else
        local m x ok
        for m in "${mods[@]}"; do
            ok=0
            for x in "${MODULES[@]}"; do
                if [ "$m" = "$x" ]; then
                    ok=1
                    break
                fi
            done
            if [ "$ok" != 1 ]; then
                printf 'unknown module: %s\nmodules: %s\n' "$m" "${MODULES[*]}" >&2
                exit 2
            fi
        done
    fi

    if [ "$action" = restore ]; then
        # packages/fish/macos need sudo (brew services, chsh, defaults edge cases);
        # put also falls back to sudo on root-owned destinations.
        local needs_sudo=0
        for m in "${mods[@]}"; do
            case "$m" in packages | fish | macos) needs_sudo=1 ;; esac
        done
        if [ "$needs_sudo" = 1 ]; then sudo_keepalive; fi
        trap 'stop_keepalive' EXIT
        # brew must exist before packages/fisher/etc. run.
        for m in "${mods[@]}"; do
            if [ "$m" = packages ]; then ensure_brew; fi
        done
    else
        # Captures write straight into the worktree — git is the safety net.
        trap 'rc=$?; [ $rc -eq 0 ] || warn "update failed; repo may be partially updated — check git status/diff."' EXIT
    fi

    for m in "${mods[@]}"; do
        step "$action $m"
        "${action}_${m//-/_}"
    done

    if [ "$action" = update ]; then strip_trailing_ws; fi
    step "done"
}

main "$@"
