# update.sh Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `./update.sh` a pure mirror of the live machine back into the repo, with unchanged snapshot failures, rollback on apply failures, and explicit degraded-state reporting if rollback itself fails.

**Architecture:** Stage the desired repo snapshot in a temp tree under the repo filesystem first, then apply it to tracked targets with backup-and-restore logic. Treat missing live sources as intentional deletions, while keeping generator failures and other snapshot failures from mutating the repo. If rollback fails, keep the temp artifacts for inspection and report the degraded state explicitly.

**Tech Stack:** Bash, Python `unittest`, repo-local temp directories, trap-based cleanup

---

### Task 1: Add regression tests for pure mirror semantics

**Files:**
- Modify: `tests/test_dotfiles.py`
- Test: `tests/test_dotfiles.py`

- [ ] **Step 1: Write failing pruning and generator-safety tests**

```python
def test_update_prunes_missing_managed_sources_from_repo(self):
    self.seed_update_sources()

    shutil.rmtree(self.home / ".claude" / "agents")
    shutil.rmtree(self.home / ".config" / "opencode" / "prompts")
    (self.home / ".gitconfig").unlink()

    stale_agent = self.fixture / "claude" / "agents" / "stale.md"
    stale_prompt = self.fixture / "opencode" / "prompts" / "stale.md"
    stale_gitconfig = self.fixture / "git" / ".gitconfig"

    stale_agent.write_text("stale\n", encoding="utf-8")
    stale_prompt.write_text("stale\n", encoding="utf-8")
    stale_gitconfig.write_text("stale\n", encoding="utf-8")

    result = self.run_cmd("bash", "update.sh")

    self.assertEqual(result.returncode, 0, msg=result.stderr)
    self.assertFalse(stale_agent.exists())
    self.assertFalse(stale_prompt.exists())
    self.assertFalse(stale_gitconfig.exists())


def test_update_keeps_repo_unchanged_when_fisher_list_fails(self):
    self.seed_update_sources()
    tracked_file = self.fixture / "fish" / "config.fish"
    original = tracked_file.read_text(encoding="utf-8")

    self.write_stub(
        "fish",
        """#!/bin/bash
exit 1
""",
    )

    result = self.run_cmd("bash", "update.sh")

    self.assertNotEqual(result.returncode, 0)
    self.assertEqual(tracked_file.read_text(encoding="utf-8"), original)
```

- [ ] **Step 2: Run targeted tests to verify they fail for the expected reasons**

Run: `python3 -m unittest tests.test_dotfiles.DotfilesScriptTests.test_update_prunes_missing_managed_sources_from_repo tests.test_dotfiles.DotfilesScriptTests.test_update_keeps_repo_unchanged_when_fisher_list_fails -v`
Expected: first test fails because `update.sh` exits on missing `.gitconfig` instead of pruning it; second test fails because earlier repo files already changed before the fish failure.

- [ ] **Step 3: Expand generator coverage for successful Fisher output and Brew failure safety**

```python
def test_update_generates_fisher_manifest_from_live_plugin_list(self):
    self.seed_update_sources()

    result = self.run_cmd(
        "bash",
        "update.sh",
        extra_env={
            "FAKE_FISH_LIST_OUTPUT": "jorgebucaran/fisher\njorgebucaran/autopair.fish\nPatrickF1/fzf.fish\n",
        },
    )

    self.assertEqual(result.returncode, 0, msg=result.stderr)
    self.assertEqual(
        (self.fixture / "fisher" / "fisher install.list").read_text(encoding="utf-8"),
        "jorgebucaran/autopair.fish\nPatrickF1/fzf.fish\n",
    )


def test_update_keeps_repo_unchanged_when_brew_dump_fails(self):
    self.seed_update_sources()
    tracked_file = self.fixture / "fish" / "config.fish"
    original = tracked_file.read_text(encoding="utf-8")

    self.write_stub(
        "brew",
        """#!/bin/bash
exit 1
""",
    )

    result = self.run_cmd("bash", "update.sh")

    self.assertNotEqual(result.returncode, 0)
    self.assertEqual(tracked_file.read_text(encoding="utf-8"), original)
```

- [ ] **Step 4: Run the new update-focused tests again**

Run: `python3 -m unittest tests.test_dotfiles.DotfilesScriptTests.test_update_prunes_missing_managed_sources_from_repo tests.test_dotfiles.DotfilesScriptTests.test_update_keeps_repo_unchanged_when_fisher_list_fails tests.test_dotfiles.DotfilesScriptTests.test_update_generates_fisher_manifest_from_live_plugin_list tests.test_dotfiles.DotfilesScriptTests.test_update_keeps_repo_unchanged_when_brew_dump_fails -v`
Expected: FAIL until `update.sh` is hardened.

### Task 2: Rebuild `update.sh` around staged snapshot and safe apply

**Files:**
- Modify: `update.sh`
- Test: `tests/test_dotfiles.py`

- [ ] **Step 1: Replace direct-write helpers with staged snapshot helpers**

```bash
stage_file() {
    local source="$1"
    local relative_target="$2"
    local staged_target="$STAGE_DIR/$relative_target"

    if [ ! -e "$source" ] && [ ! -h "$source" ]; then
        return 0
    fi

    mkdir -p "$(dirname "$staged_target")"
    cp -R "$source" "$staged_target"
}

stage_directory() {
    local source_dir="$1"
    local relative_target="$2"
    local staged_target="$STAGE_DIR/$relative_target"

    if [ ! -d "$source_dir" ]; then
        return 0
    fi

    mkdir -p "$staged_target"
    cp -R "$source_dir"/. "$staged_target"/
}
```

- [ ] **Step 2: Stage generated artifacts instead of writing into tracked files**

```bash
generate_fisher_manifest() {
    local staged_target="$STAGE_DIR/fisher/fisher install.list"
    local fish_plugins

    fish_plugins="$(fish -c 'fisher list')"
    mkdir -p "$(dirname "$staged_target")"
    : > "$staged_target"

    while IFS= read -r plugin; do
        if [ -n "$plugin" ] && [ "$plugin" != "jorgebucaran/fisher" ]; then
            printf '%s\n' "$plugin" >> "$staged_target"
        fi
    done <<< "$fish_plugins"
}

generate_brewfile() {
    mkdir -p "$STAGE_DIR/packages"
    brew bundle dump --force --describe --file="$STAGE_DIR/packages/Brewfile"
}
```

- [ ] **Step 3: Add apply helpers with per-target backup, rollback, and rollback diagnostics**

```bash
restore_backups() {
    local rollback_failed=0
    local index relative_target target_path backup_path

    for ((index=${#APPLIED_TARGETS[@]}-1; index>=0; index--)); do
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
    local backup_path="$BACKUP_DIR/$relative_target"
    local staged_target="$STAGE_DIR/$relative_target"

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
```

- [ ] **Step 4: Wire the staged snapshot/apply flow with explicit target registration**

```bash
stage_file "$HOME/.gitconfig" "git/.gitconfig"
stage_directory "$HOME/.claude/agents" "claude/agents"
stage_file "$HOME/.config/opencode/dcp.jsonc" "opencode/dcp.jsonc"

generate_fisher_manifest
generate_brewfile
# Keep the legacy repo-only agent directory pruned.
track_target "opencode/agent"
apply_staged_targets
```

- [ ] **Step 5: Run update-focused tests to verify they pass**

Run: `python3 -m unittest tests.test_dotfiles.DotfilesScriptTests.test_update_backs_up_curated_opencode_files tests.test_dotfiles.DotfilesScriptTests.test_update_handles_empty_fisher_plugin_list tests.test_dotfiles.DotfilesScriptTests.test_update_generates_fisher_manifest_from_live_plugin_list tests.test_dotfiles.DotfilesScriptTests.test_update_generates_brewfile_from_brew_bundle_dump tests.test_dotfiles.DotfilesScriptTests.test_update_cleans_repo_local_temp_artifacts_on_success tests.test_dotfiles.DotfilesScriptTests.test_update_cleans_repo_local_temp_artifacts_on_snapshot_failure tests.test_dotfiles.DotfilesScriptTests.test_update_prunes_missing_managed_sources_from_repo tests.test_dotfiles.DotfilesScriptTests.test_update_keeps_repo_unchanged_when_fisher_list_fails tests.test_dotfiles.DotfilesScriptTests.test_update_keeps_repo_unchanged_when_brew_dump_fails tests.test_dotfiles.DotfilesScriptTests.test_update_rolls_back_repo_when_apply_phase_fails tests.test_dotfiles.DotfilesScriptTests.test_update_keeps_repo_unchanged_when_backup_move_fails tests.test_dotfiles.DotfilesScriptTests.test_update_reports_rollback_failures tests.test_dotfiles.DotfilesScriptTests.test_update_prunes_legacy_opencode_agent_directory -v`
Expected: PASS

### Task 3: Update docs and verify the full suite

**Files:**
- Modify: `README.md`
- Test: `tests/test_dotfiles.py`

- [ ] **Step 1: Update `README.md` to describe pure mirror behavior**

```markdown
Run this to sync the live machine back into the repo:

`./update.sh`

This builds a temp mirror of the current machine state into staged repo paths before apply.
If a managed live source no longer exists, `./update.sh` removes the corresponding repo snapshot.
If snapshot or generation fails, the repo stays unchanged. If apply fails, `./update.sh` attempts rollback; if rollback also fails, it reports that the repo may be partially updated and keeps the rollback artifacts path for inspection.
```

- [ ] **Step 2: Run the full regression suite**

Run: `python3 -m unittest discover -s tests -p 'test_*.py' -v`
Expected: PASS

- [ ] **Step 3: Review the final diff for scope control**

Run: `git diff -- update.sh tests/test_dotfiles.py README.md docs/superpowers/specs/2026-03-27-update-sh-hardening-design.md docs/superpowers/plans/2026-03-27-update-sh-hardening.md`
Expected: only the hardening work, docs, and tests are present.
