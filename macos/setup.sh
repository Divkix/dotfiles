#!/bin/bash

# shellcheck source=../scripts/functions.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

. ../scripts/functions.sh

MANIFEST="defaults.list"

# `defaults` only exists on macOS, so its absence is the platform check.
if ! command -v defaults >/dev/null 2>&1; then
    info "Not macOS; skipping macOS settings."
    exit 0
fi

info "Applying macOS settings..."

failed=0

# Manifest lines are tab-separated: "<domain> <key> <type> <value>", with type as printed by
# `defaults read-type` (boolean, integer, float, string). A failing key is reported but does
# not stop the rest: some domains (e.g. com.apple.universalaccess) need extra privacy grants.
while IFS=$'\t' read -r domain key type value || [ -n "$domain" ]; do
    case "$domain" in
    "" | \#*)
        continue
        ;;
    esac

    case "$type" in
    boolean)
        if [ "$value" = "1" ]; then value=true; else value=false; fi
        flag="-bool"
        ;;
    integer) flag="-int" ;;
    float) flag="-float" ;;
    string) flag="-string" ;;
    *)
        substep_error "Unsupported type '$type' for $domain $key; skipping."
        failed=$((failed + 1))
        continue
        ;;
    esac

    if ! defaults write "$domain" "$key" "$flag" "$value" </dev/null; then
        substep_error "Failed writing $domain $key."
        failed=$((failed + 1))
    fi
done <"$MANIFEST"

# Dock, Finder and the menu bar only re-read preferences on restart. Trackpad and global
# keys may need a log out and back in.
for app in Dock Finder SystemUIServer; do
    killall "$app" >/dev/null 2>&1 || true
done

if [ "$failed" -gt 0 ]; then
    substep_error "$failed setting(s) failed; re-run macos/setup.sh later."
else
    success "Finished applying macOS settings. Log out and back in for trackpad and global changes."
fi
