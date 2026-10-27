#!/usr/bin/env bash
# Close the focused herdr workspace and delete its worktree checkout.
# Non-worktree workspaces just close. Worktree removal goes through `wt remove`,
# so worktrunk keeps its own approval prompt, refuses dirty checkouts, and
# deletes the branch only when it is merged.
set -u

herdr=${HERDR_BIN_PATH:-herdr}
ws=${HERDR_ACTIVE_WORKSPACE_ID:?HERDR_ACTIVE_WORKSPACE_ID is not set}
cwd=${HERDR_ACTIVE_PANE_CWD:-$PWD}

# Herdr only lists worktrees for a cwd inside a Git work tree; a workspace
# outside Git (not_git_worktree) has nothing to delete, so treat any lookup
# failure as close-only.
items=$("$herdr" worktree list --cwd "$cwd" --json 2>/dev/null) || items=''

# Only a linked worktree can be removed; the primary checkout carries its own
# open_workspace_id too and must never reach `wt remove`.
path=$(jq -r --arg ws "$ws" \
  '.result.worktrees[] | select(.is_linked_worktree == true and .open_workspace_id == $ws) | .path' \
  <<<"$items" 2>/dev/null | head -n1)

if [[ -z $path ]]; then
  # Plain workspace: just close. Herdr refuses (and nothing closes) when this is a
  # primary workspace with linked worktree workspaces still open.
  "$herdr" workspace close "$ws" || {
    printf '\n\033[31m%s\033[0m\n' "workspace not closed"
    read -rn1
  }
  exit 0
fi

branch=$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null) || {
  printf '\033[31m%s\033[0m\n' "$path is not a git checkout"
  read -rn1
  exit 1
}
main=$(jq -r '.result.worktrees[] | select(.is_linked_worktree == false) | .path' <<<"$items" | head -n1)

# `wt remove` does not confirm anything itself (its approval prompts only cover
# first-time project hook commands), so ask here.
printf 'Delete worktree %s (%s) and close the workspace? [y/N] ' "$path" "$branch"
read -r answer || answer=''
[[ $answer == [yY]* ]] || exit 0

printf '\nRemoving worktree %s (%s)\n\n' "$path" "$branch"
if ! wt remove --foreground -C "$main" "$branch"; then
  printf '\n\033[31m%s\033[0m workspace kept\n' "wt remove failed"
  read -rn1
  exit 1
fi

"$herdr" workspace close "$ws"
