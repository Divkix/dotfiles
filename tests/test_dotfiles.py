import json
import os
import re
import shutil
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class DotfilesScriptTests(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        self.fixture = self.root / "repo"
        shutil.copytree(
            REPO_ROOT,
            self.fixture,
            ignore=shutil.ignore_patterns(".git", ".DS_Store", "__pycache__"),
        )

        self.home = self.root / "home"
        self.home.mkdir()
        self.bin_dir = self.root / "bin"
        self.bin_dir.mkdir()
        self.logs_dir = self.root / "logs"
        self.logs_dir.mkdir()

        self.sudo_log = self.logs_dir / "sudo.log"
        self.fish_log = self.logs_dir / "fish.log"
        self.fisher_log = self.logs_dir / "fisher.log"
        self.brew_log = self.logs_dir / "brew.log"

        self.write_stub(
            "sudo",
            """#!/bin/bash
printf '%s\n' \"$*\" >> \"$FAKE_SUDO_LOG\"

if [ \"${1:-}\" = \"-v\" ] || [ \"${1:-}\" = \"-n\" ]; then
    exit 0
fi

if [ \"${1:-}\" = \"mkdir\" ] && [ \"${2:-}\" = \"-p\" ] && [ \"${FAKE_SUDO_MKDIR_READONLY:-}\" = \"1\" ]; then
    \"$@\"
    chmod 555 \"${@: -1}\"
    exit 0
fi

exec \"$@\"
""",
        )
        self.write_stub(
            "tput",
            """#!/bin/bash
exit 0
""",
        )
        self.write_stub(
            "fish",
            """#!/bin/bash
printf '%s\n' \"$*\" >> \"$FAKE_FISH_LOG\"

if [ \"${1:-}\" = \"-c\" ] && [ -n \"${FAKE_FISH_LIST_OUTPUT:-}\" ]; then
    printf '%s' \"$FAKE_FISH_LIST_OUTPUT\"
fi

exit 0
""",
        )
        self.write_stub(
            "fisher",
            """#!/bin/bash
printf '%s\n' \"$*\" >> \"$FAKE_FISHER_LOG\"
exit 0
""",
        )
        self.write_stub(
            "brew",
            """#!/bin/bash
printf '%s\n' "$*" >> "$FAKE_BREW_LOG"

for arg in "$@"; do
    case "$arg" in
        --file=*)
            brewfile="${arg#--file=}"
            mkdir -p "$(dirname "$brewfile")"
            printf 'tap "homebrew/bundle"\n' > "$brewfile"
            ;;
    esac
done

exit 0
""",
        )

        self.env = os.environ.copy()
        self.env.update(
            {
                "HOME": str(self.home),
                "PATH": f"{self.bin_dir}:{self.env['PATH']}",
                "TERM": "xterm",
                "FAKE_FISH_LOG": str(self.fish_log),
                "FAKE_FISHER_LOG": str(self.fisher_log),
                "FAKE_BREW_LOG": str(self.brew_log),
                "FAKE_SUDO_LOG": str(self.sudo_log),
            }
        )

    def tearDown(self):
        self.tempdir.cleanup()

    def write_stub(self, name: str, content: str) -> None:
        path = self.bin_dir / name
        path.write_text(textwrap.dedent(content), encoding="utf-8")
        path.chmod(0o755)

    def write_file(self, path: Path, content: str) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    def run_cmd(
        self,
        *args: str,
        cwd: Path | None = None,
        extra_env: dict[str, str] | None = None,
        timeout: float | None = None,
    ):
        env = self.env.copy()
        if extra_env:
            env.update(extra_env)

        return subprocess.run(
            [*args],
            cwd=cwd or self.fixture,
            env=env,
            capture_output=True,
            text=True,
            timeout=timeout,
        )

    def snapshot_repo_paths(self, *relative_paths: str) -> dict[str, tuple[str, str | None]]:
        snapshot: dict[str, tuple[str, str | None]] = {}

        for relative_path in relative_paths:
            target = self.fixture / relative_path
            relative_key = target.relative_to(self.fixture).as_posix()

            if not target.exists() and not target.is_symlink():
                snapshot[relative_key] = ("missing", None)
                continue

            if target.is_symlink():
                snapshot[relative_key] = ("symlink", os.readlink(target))
                continue

            if target.is_file():
                snapshot[relative_key] = ("file", target.read_text(encoding="utf-8"))
                continue

            snapshot[relative_key] = ("dir", None)
            for child in sorted(target.rglob("*")):
                child_relative = child.relative_to(self.fixture).as_posix()
                if child.is_symlink():
                    snapshot[child_relative] = ("symlink", os.readlink(child))
                elif child.is_file():
                    snapshot[child_relative] = ("file", child.read_text(encoding="utf-8"))
                else:
                    snapshot[child_relative] = ("dir", None)

        return snapshot

    def snapshot_managed_repo(self) -> dict[str, tuple[str, str | None]]:
        return self.snapshot_repo_paths(
            "fish",
            "claude",
            "opencode",
            "ghostty",
            "fisher",
            "git",
            "ssh",
            "gnupg",
            "packages",
            "starship",
        )

    def test_scopy_keeps_existing_destination_when_copy_fails(self):
        destination = self.root / "existing.conf"
        destination.write_text("keep me\n", encoding="utf-8")

        result = self.run_cmd(
            "bash",
            "-c",
            '. scripts/functions.sh; scopy "$SOURCE_PATH" "$DESTINATION_PATH"',
            extra_env={
                "SOURCE_PATH": str(self.root / "missing.conf"),
                "DESTINATION_PATH": str(destination),
            },
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(destination.exists())
        self.assertEqual(destination.read_text(encoding="utf-8"), "keep me\n")

    def test_bootstrap_runs_packages_first_and_setup_scripts_in_sorted_order(self):
        bootstrap_log = self.logs_dir / "bootstrap.log"
        setup_paths = sorted(self.fixture.glob("*/setup.sh"))

        for setup_path in setup_paths:
            module = setup_path.parent.name
            self.write_file(
                setup_path,
                (f"#!/bin/bash\nprintf '%s\\n' '{module}' >> '{bootstrap_log}'\n"),
            )
            setup_path.chmod(0o755)

        result = self.run_cmd("bash", "bootstrap.sh", timeout=5)

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertEqual(
            bootstrap_log.read_text(encoding="utf-8").splitlines(),
            ["packages"]
            + sorted(
                setup_path.parent.name
                for setup_path in setup_paths
                if setup_path.parent.name != "packages"
            ),
        )

    def test_bootstrap_stops_after_first_failing_setup_script(self):
        bootstrap_log = self.logs_dir / "bootstrap.log"
        setup_paths = sorted(self.fixture.glob("*/setup.sh"))
        failing_module = "ghostty"

        for setup_path in setup_paths:
            module = setup_path.parent.name
            exit_code = 1 if module == failing_module else 0
            self.write_file(
                setup_path,
                (
                    "#!/bin/bash\n"
                    f"printf '%s\\n' '{module}' >> '{bootstrap_log}'\n"
                    f"exit {exit_code}\n"
                ),
            )
            setup_path.chmod(0o755)

        result = self.run_cmd("bash", "bootstrap.sh", timeout=5)

        self.assertNotEqual(result.returncode, 0)
        expected_modules = [
            "packages",
            *sorted(
                setup_path.parent.name
                for setup_path in setup_paths
                if setup_path.parent.name != "packages"
            ),
        ]
        self.assertEqual(
            bootstrap_log.read_text(encoding="utf-8").splitlines(),
            expected_modules[: expected_modules.index(failing_module) + 1],
        )

    def test_scopy_creates_nested_parent_without_sudo_owned_tempdir(self):
        source = self.root / "source.conf"
        source.write_text("nested\n", encoding="utf-8")
        destination = self.home / ".config" / "opencode" / "prompts" / "custom.md"

        result = self.run_cmd(
            "bash",
            "-c",
            '. scripts/functions.sh; scopy "$SOURCE_PATH" "$DESTINATION_PATH"',
            extra_env={
                "SOURCE_PATH": str(source),
                "DESTINATION_PATH": str(destination),
                "FAKE_SUDO_MKDIR_READONLY": "1",
            },
        )

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertTrue(destination.exists())
        self.assertEqual(destination.read_text(encoding="utf-8"), "nested\n")
        sudo_calls = []
        if self.sudo_log.exists():
            sudo_calls = self.sudo_log.read_text(encoding="utf-8").splitlines()
        self.assertFalse(
            any(
                call.startswith(prefix)
                for call in sudo_calls
                for prefix in ("mkdir ", "cp ", "mv ")
            )
        )

    def test_claude_setup_restores_nested_files_and_root_config(self):
        result = self.run_cmd("bash", "claude/setup.sh")

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertTrue((self.home / ".claude" / "CLAUDE.md").exists())
        self.assertTrue(
            (self.home / ".claude" / "agents" / "github-actions-expert.md").exists()
        )
        self.assertTrue(
            (self.home / ".claude" / "commands" / "review-code.md").exists()
        )
        self.assertTrue((self.home / ".claude.json").exists())
        self.assertFalse((self.home / ".claude" / "claude.json").exists())

    def test_claude_setup_prunes_stale_managed_subtrees(self):
        self.write_file(self.home / ".claude" / "agents" / "stale.md", "stale\n")
        self.write_file(self.home / ".claude" / "commands" / "stale.md", "stale\n")

        result = self.run_cmd("bash", "claude/setup.sh")

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertFalse((self.home / ".claude" / "agents" / "stale.md").exists())
        self.assertFalse((self.home / ".claude" / "commands" / "stale.md").exists())
        self.assertTrue(
            (self.home / ".claude" / "agents" / "github-actions-expert.md").exists()
        )
        self.assertTrue(
            (self.home / ".claude" / "commands" / "review-code.md").exists()
        )

    def test_opencode_setup_restores_prompts_and_dcp_on_first_run(self):
        prompts_dir = self.fixture / "opencode" / "prompts"
        prompts_dir.mkdir(parents=True, exist_ok=True)
        self.write_file(prompts_dir / "custom.md", "prompt\n")
        self.write_file(
            self.fixture / "opencode" / "dcp.jsonc",
            '{"$schema":"https://example.com/schema"}\n',
        )

        result = self.run_cmd("bash", "opencode/setup.sh")

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertTrue((self.home / ".config" / "opencode" / "opencode.json").exists())
        self.assertTrue((self.home / ".config" / "opencode" / "AGENTS.md").exists())
        self.assertTrue((self.home / ".config" / "opencode" / "dcp.jsonc").exists())
        self.assertTrue(
            (self.home / ".config" / "opencode" / "prompts" / "custom.md").exists()
        )

    def test_opencode_setup_prunes_stale_managed_files(self):
        stale_root = self.home / ".config" / "opencode"
        self.write_file(stale_root / "prompts" / "stale.md", "stale\n")
        self.write_file(stale_root / "agent" / "legacy.md", "legacy\n")
        self.write_file(stale_root / "dcp.jsonc", '{"stale":true}\n')

        (self.fixture / "opencode" / "dcp.jsonc").unlink(missing_ok=True)

        result = self.run_cmd("bash", "opencode/setup.sh")

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertFalse((stale_root / "prompts" / "stale.md").exists())
        self.assertFalse((stale_root / "agent").exists())
        self.assertFalse((stale_root / "dcp.jsonc").exists())
        self.assertTrue((stale_root / "opencode.json").exists())

    def test_opencode_setup_fails_when_legacy_agent_cleanup_fails(self):
        stale_root = self.home / ".config" / "opencode"
        self.write_file(stale_root / "agent" / "legacy.md", "legacy\n")
        agent_dir = stale_root / "agent"

        self.write_stub(
            "rm",
            f"""#!/bin/bash
if [ \"${{1:-}}\" = \"-rf\" ] && [ \"${{2:-}}\" = \"{agent_dir}\" ]; then
    exit 1
fi

exec /bin/rm \"$@\"
""",
        )

        result = self.run_cmd("bash", "opencode/setup.sh")

        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(agent_dir.exists())

    def test_ghostty_and_starship_create_first_run_destinations(self):
        ghostty_result = self.run_cmd("bash", "ghostty/setup.sh")
        starship_result = self.run_cmd("bash", "starship/setup.sh")

        self.assertEqual(ghostty_result.returncode, 0, msg=ghostty_result.stderr)
        self.assertEqual(starship_result.returncode, 0, msg=starship_result.stderr)
        self.assertTrue((self.home / ".config" / "ghostty" / "config").exists())
        self.assertTrue((self.home / ".config" / "starship.toml").exists())

    def test_fisher_setup_installs_each_plugin_once(self):
        list_file = self.fixture / "fisher" / "fisher install.list"
        list_file.write_text("jorgebucaran/autopair.fish\n", encoding="utf-8")

        result = self.run_cmd("bash", "fisher/setup.sh")

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        fish_calls = self.fish_log.read_text(encoding="utf-8").splitlines()
        install_calls = [
            call
            for call in fish_calls
            if "fisher install jorgebucaran/autopair.fish" in call
        ]
        self.assertEqual(len(install_calls), 1)
        self.assertFalse(
            any(
                "install install jorgebucaran/autopair.fish" in call
                for call in fish_calls
            )
        )

    def test_fisher_setup_installs_plugins_through_fish_shell(self):
        list_file = self.fixture / "fisher" / "fisher install.list"
        list_file.write_text("jorgebucaran/autopair.fish\n", encoding="utf-8")
        self.write_stub(
            "fisher",
            """#!/bin/bash
exit 127
""",
        )

        result = self.run_cmd("bash", "fisher/setup.sh")

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        fish_calls = self.fish_log.read_text(encoding="utf-8").splitlines()
        self.assertTrue(
            any(
                "fisher install jorgebucaran/autopair.fish" in call
                for call in fish_calls
            )
        )

    def test_update_backs_up_curated_opencode_files(self):
        self.seed_update_sources()

        result = self.run_cmd("bash", "update.sh")

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertTrue((self.fixture / "opencode" / "opencode.json").exists())
        self.assertTrue((self.fixture / "opencode" / "AGENTS.md").exists())
        self.assertTrue((self.fixture / "opencode" / "dcp.jsonc").exists())
        self.assertTrue((self.fixture / "opencode" / "prompts" / "custom.md").exists())

    def test_update_handles_empty_fisher_plugin_list(self):
        self.seed_update_sources()
        manifest = self.fixture / "fisher" / "fisher install.list"
        manifest.write_text("stale-plugin\n", encoding="utf-8")

        result = self.run_cmd(
            "bash",
            "update.sh",
            extra_env={"FAKE_FISH_LIST_OUTPUT": "jorgebucaran/fisher\n"},
        )

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertEqual(manifest.read_text(encoding="utf-8"), "")

    def test_update_generates_fisher_manifest_from_live_plugin_list(self):
        self.seed_update_sources()
        manifest = self.fixture / "fisher" / "fisher install.list"

        result = self.run_cmd(
            "bash",
            "update.sh",
            extra_env={
                "FAKE_FISH_LIST_OUTPUT": (
                    "jorgebucaran/fisher\n"
                    "jorgebucaran/autopair.fish\n"
                    "PatrickF1/fzf.fish\n"
                )
            },
        )

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertEqual(
            manifest.read_text(encoding="utf-8"),
            "jorgebucaran/autopair.fish\nPatrickF1/fzf.fish\n",
        )

    def test_update_generates_brewfile_from_brew_bundle_dump(self):
        self.seed_update_sources()
        brewfile = self.fixture / "packages" / "Brewfile"

        result = self.run_cmd("bash", "update.sh")

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertEqual(brewfile.read_text(encoding="utf-8"), 'tap "homebrew/bundle"\n')

    def test_update_cleans_repo_local_temp_artifacts_on_success(self):
        self.seed_update_sources()

        result = self.run_cmd("bash", "update.sh")

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertEqual(list(self.fixture.glob(".update.sh.*")), [])

    def test_update_cleans_repo_local_temp_artifacts_on_snapshot_failure(self):
        self.seed_update_sources()

        self.write_stub(
            "fish",
            """#!/bin/bash
exit 1
""",
        )

        result = self.run_cmd("bash", "update.sh")

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(list(self.fixture.glob(".update.sh.*")), [])

    def test_update_prunes_missing_managed_sources_from_repo(self):
        self.seed_update_sources()

        shutil.rmtree(self.home / ".claude" / "agents")
        shutil.rmtree(self.home / ".config" / "opencode" / "prompts")
        (self.home / ".gitconfig").unlink()

        result = self.run_cmd("bash", "update.sh")

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertFalse((self.fixture / "claude" / "agents").exists())
        self.assertFalse((self.fixture / "opencode" / "prompts").exists())
        self.assertFalse((self.fixture / "git" / ".gitconfig").exists())

    def test_update_keeps_repo_unchanged_when_fisher_list_fails(self):
        self.seed_update_sources()
        expected = self.snapshot_managed_repo()

        self.write_stub(
            "fish",
            """#!/bin/bash
exit 1
""",
        )

        result = self.run_cmd("bash", "update.sh")

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.snapshot_managed_repo(), expected)

    def test_update_keeps_repo_unchanged_when_brew_dump_fails(self):
        self.seed_update_sources()
        expected = self.snapshot_managed_repo()

        self.write_stub(
            "brew",
            """#!/bin/bash
exit 1
""",
        )

        result = self.run_cmd(
            "bash",
            "update.sh",
            extra_env={
                "FAKE_FISH_LIST_OUTPUT": "jorgebucaran/fisher\nPatrickF1/fzf.fish\n"
            },
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.snapshot_managed_repo(), expected)

    def test_update_rolls_back_repo_when_apply_phase_fails(self):
        self.seed_update_sources()
        self.write_file(self.fixture / "fish" / "config.fish", "repo fish\n")
        self.write_file(self.fixture / "claude" / "settings.json", '{"repo":true}\n')
        self.write_file(self.fixture / "packages" / "Brewfile", 'tap "repo/stale"\n')
        expected = self.snapshot_managed_repo()
        fail_marker = self.root / "mv-failed"

        self.write_stub(
            "mv",
            f"""#!/bin/bash
if [ "${{1:-}}" != "${{1##*/stage/claude/settings.json}}" ] && [ ! -e "{fail_marker}" ]; then
    : > "{fail_marker}"
    exit 1
fi

exec /bin/mv "$@"
""",
        )

        result = self.run_cmd(
            "bash",
            "update.sh",
            extra_env={
                "FAKE_FISH_LIST_OUTPUT": "jorgebucaran/fisher\nPatrickF1/fzf.fish\n"
            },
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(fail_marker.exists())
        self.assertEqual(self.snapshot_managed_repo(), expected)

    def test_update_keeps_repo_unchanged_when_backup_move_fails(self):
        self.seed_update_sources()
        self.write_file(self.fixture / "fish" / "config.fish", "repo fish\n")
        expected = self.snapshot_managed_repo()
        fail_marker = self.root / "mv-backup-failed"

        self.write_stub(
            "mv",
            f"""#!/bin/bash
if [ "${{2:-}}" != "${{2##*/backup/fish/config.fish}}" ] && [ ! -e "{fail_marker}" ]; then
    : > "{fail_marker}"
    exit 1
fi

exec /bin/mv "$@"
""",
        )

        result = self.run_cmd(
            "bash",
            "update.sh",
            extra_env={
                "FAKE_FISH_LIST_OUTPUT": "jorgebucaran/fisher\nPatrickF1/fzf.fish\n"
            },
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(fail_marker.exists())
        self.assertEqual(self.snapshot_managed_repo(), expected)

    def test_update_reports_rollback_failures(self):
        self.seed_update_sources()
        self.write_file(self.fixture / "fish" / "config.fish", "repo fish\n")
        self.write_file(self.fixture / "claude" / "settings.json", '{"repo":true}\n')
        expected = self.snapshot_managed_repo()
        expected.pop("fish/config.fish", None)
        apply_marker = self.root / "mv-apply-failed"
        rollback_marker = self.root / "mv-rollback-failed"

        self.write_stub(
            "mv",
            f"""#!/bin/bash
if [ "${{1:-}}" != "${{1##*/stage/claude/settings.json}}" ] && [ ! -e "{apply_marker}" ]; then
    : > "{apply_marker}"
    exit 1
fi

if [ "${{1:-}}" != "${{1##*/backup/fish/config.fish}}" ] && [ ! -e "{rollback_marker}" ]; then
    : > "{rollback_marker}"
    exit 1
fi

exec /bin/mv "$@"
""",
        )

        result = self.run_cmd(
            "bash",
            "update.sh",
            extra_env={
                "FAKE_FISH_LIST_OUTPUT": "jorgebucaran/fisher\nPatrickF1/fzf.fish\n"
            },
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(apply_marker.exists())
        self.assertTrue(rollback_marker.exists())
        self.assertIn("Rollback failed", result.stderr)
        temp_dir_match = re.search(r"Rollback artifacts kept at (.+)", result.stderr)
        self.assertIsNotNone(temp_dir_match, msg=result.stderr)
        artifacts_dir = Path(temp_dir_match.group(1).strip())
        self.assertTrue(artifacts_dir.is_dir())
        self.assertEqual(artifacts_dir.parent.resolve(), self.fixture.resolve())
        self.assertTrue(artifacts_dir.name.startswith(".update.sh."))
        current = self.snapshot_managed_repo()
        self.assertNotIn("fish/config.fish", current)
        self.assertEqual(current, expected)

    def test_update_prunes_legacy_opencode_agent_directory(self):
        self.seed_update_sources()
        self.write_file(self.fixture / "opencode" / "agent" / "legacy.md", "legacy\n")

        result = self.run_cmd("bash", "update.sh")

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertFalse((self.fixture / "opencode" / "agent").exists())

    def test_ssh_setup_restores_config(self):
        result = self.run_cmd("bash", "ssh/setup.sh")

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        config_path = self.home / ".ssh" / "config"
        self.assertTrue(config_path.exists())
        self.assertEqual(
            config_path.read_text(encoding="utf-8"),
            (self.fixture / "ssh" / "config").read_text(encoding="utf-8"),
        )

    def test_gnupg_setup_restores_files_with_secure_permissions(self):
        result = self.run_cmd("bash", "gnupg/setup.sh")

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        gnupg_dir = self.home / ".gnupg"
        gpg_conf = gnupg_dir / "gpg.conf"
        gpg_agent_conf = gnupg_dir / "gpg-agent.conf"

        self.assertTrue(gpg_conf.exists())
        self.assertTrue(gpg_agent_conf.exists())
        self.assertEqual(gnupg_dir.stat().st_mode & 0o777, 0o700)
        self.assertEqual(gpg_conf.stat().st_mode & 0o777, 0o600)
        self.assertEqual(gpg_agent_conf.stat().st_mode & 0o777, 0o600)

    def test_opencode_config_uses_matching_github_actions_prompt(self):
        config = json.loads(
            (self.fixture / "opencode" / "opencode.json").read_text(encoding="utf-8")
        )

        self.assertEqual(
            config["agent"]["github-actions-pro"]["prompt"],
            "{file:./prompts/github-actions-expert.md}",
        )

    def test_opencode_config_uses_matching_typescript_prompt(self):
        config = json.loads(
            (self.fixture / "opencode" / "opencode.json").read_text(encoding="utf-8")
        )

        self.assertEqual(
            config["agent"]["typescript-pro"]["prompt"],
            "{file:./prompts/typescript-pro.md}",
        )

    def test_opencode_config_uses_relative_instructions_path(self):
        config = json.loads(
            (self.fixture / "opencode" / "opencode.json").read_text(encoding="utf-8")
        )

        self.assertEqual(config["instructions"], ["AGENTS.md"])

    def seed_update_sources(self) -> None:
        fish_dir = self.home / ".config" / "fish"
        self.write_file(fish_dir / "config.fish", "set -g theme test\n")
        self.write_file(
            fish_dir / "functions" / "fish_prompt.fish", "function fish_prompt; end\n"
        )
        self.write_file(
            fish_dir / "functions" / "fish_greeting.fish",
            "function fish_greeting; end\n",
        )
        self.write_file(
            fish_dir / "functions" / "fish_prompt_loading_indicator.fish",
            "function fish_prompt_loading_indicator; end\n",
        )
        self.write_file(fish_dir / "conf.d" / "abbr.fish", "abbr gs 'git status'\n")
        self.write_file(fish_dir / "conf.d" / "alias.fish", "alias ll='ls -la'\n")

        claude_dir = self.home / ".claude"
        self.write_file(claude_dir / "settings.json", "{}\n")
        self.write_file(claude_dir / "CLAUDE.md", "# Claude\n")
        self.write_file(claude_dir / "agents" / "custom.md", "agent\n")
        self.write_file(claude_dir / "commands" / "review.md", "command\n")
        self.write_file(self.home / ".claude.json", '{"theme":"system"}\n')

        opencode_dir = self.home / ".config" / "opencode"
        self.write_file(
            opencode_dir / "opencode.json",
            '{"$schema":"https://opencode.ai/config.json"}\n',
        )
        self.write_file(opencode_dir / "AGENTS.md", "# Agents\n")
        self.write_file(
            opencode_dir / "dcp.jsonc", '{"$schema":"https://example.com/schema"}\n'
        )
        self.write_file(opencode_dir / "prompts" / "custom.md", "prompt\n")

        ghostty_dir = self.home / ".config" / "ghostty"
        self.write_file(ghostty_dir / "config", "theme = light\n")

        self.write_file(self.home / ".gitconfig", "[user]\n  name = Test\n")
        self.write_file(self.home / ".gitignore_global", "node_modules\n")
        self.write_file(self.home / ".ssh" / "config", "Host *\n")

        gnupg_dir = self.home / ".gnupg"
        self.write_file(gnupg_dir / "gpg.conf", "use-agent\n")
        self.write_file(gnupg_dir / "gpg-agent.conf", "default-cache-ttl 60\n")

        self.write_file(
            self.home / ".config" / "starship.toml", "add_newline = false\n"
        )


if __name__ == "__main__":
    unittest.main()
