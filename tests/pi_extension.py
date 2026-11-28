"""Real pi RPC startup probe, isolated from personal configuration and models."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class PiExtensionTest(unittest.TestCase):
    def configure_agent(self, directory, root):
        # The pi settings template and local models: TASKBAY_PI_AGENT_DIR, else the dotfiles' pi/agent.
        source = Path(os.environ.get("TASKBAY_PI_AGENT_DIR", root.parents[1] / "pi/agent"))
        if not (source / "settings.json.template").exists():
            self.skipTest(f"no pi settings template in {source}")
        settings = json.loads((source / "settings.json.template").read_text())
        (Path(directory) / "settings.json").write_text(json.dumps(settings))
        (Path(directory) / "models.json").write_text((source / "models.json").read_text())
        return f"{settings['defaultProvider']}/{settings['defaultModel']}"

    @unittest.skipUnless(shutil.which("pi"), "pi is not installed")
    def test_lifecycle_and_foreground_delegation_contract(self):
        root = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory(prefix="pi-contract-test-") as directory:
            self.configure_agent(directory, root)
            result = subprocess.run(
                ["pi", "--mode", "rpc", "--offline", "-na", "-ne", "-ns", "-np",
                 "--no-mcp", "--no-session", "-e", str(root / "tests/fixtures/pi_extension_probe.ts")],
                input='{"type":"get_commands","id":"probe"}\n', capture_output=True, text=True, timeout=30,
                cwd=directory, env={**os.environ, "PI_CODING_AGENT_DIR": directory,
                                   "NVIM_PI_STATUS": str(Path(directory) / "status.json"), "NVIM_PI_RUN": "contract"},
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn("Failed to load extension", result.stderr)
            marker = Path(directory) / "contract-ok"
            self.assertTrue(marker.exists(), result.stdout + result.stderr + (
                (Path(directory) / "status.json").read_text() if (Path(directory) / "status.json").exists() else ""
            ))
            self.assertEqual(marker.read_text(), "ok")

    def test_cancelled_editor_exit_preserves_jobs(self):
        for choice, dirty in [("1", "no"), ("2", "yes"), ("2", "task")]:
            with self.subTest(choice=choice, dirty=dirty), tempfile.TemporaryDirectory(prefix="pi-exit-test-") as directory:
                result = subprocess.run(
                    ["nvim", "--headless", "-u", "NONE", "-i", "NONE", "-l", str(Path(__file__).resolve().parent / "exit.lua")],
                    env={**os.environ, "TASKBAY_EXIT_TEST_DIR": directory, "TASKBAY_EXIT_CHOICE": choice, "TASKBAY_EXIT_DIRTY": dirty},
                    cwd=directory, capture_output=True, text=True, timeout=10,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual((Path(directory) / "result").read_text().strip(), "preserved")

    @unittest.skipUnless(shutil.which("pi"), "pi is not installed")
    def test_pinned_extension_loads_and_publishes_lifecycle(self):
        root = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory(prefix="pi-extension-test-") as directory:
            expected_model = self.configure_agent(directory, root)
            status = Path(directory) / "status.json"
            environment = {
                **os.environ,
                "PI_CODING_AGENT_DIR": directory,
                "NVIM_PI_STATUS": str(status),
                "NVIM_PI_RUN": "test-run",
            }
            result = subprocess.run(
                ["pi", "--mode", "rpc", "--offline", "-na", "-ne", "-ns", "-np",
                 "--session-id", "issue-offline-test", "--no-mcp", "-e", str(root / "agents/pi/extension.ts")],
                input='{"type":"get_commands","id":"probe"}\n',
                text=True, capture_output=True, timeout=30, cwd=directory, env=environment,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn("Failed to load extension", result.stderr)
            replies = [json.loads(line) for line in result.stdout.splitlines() if line.startswith("{")]
            reply = next(item for item in replies if item.get("id") == "probe")
            self.assertTrue(reply["success"], reply)
            names = {item["name"] for item in reply["data"]["commands"]}
            self.assertIn("subagents-guide", names)
            self.assertNotIn("run", names, "Detached slash launchers are deliberately not exposed")
            snapshot = json.loads(status.read_text())
            self.assertEqual(snapshot["run"], "test-run")
            self.assertEqual(snapshot["cwd"], directory)
            self.assertGreater(snapshot["sequence"], 0)
            self.assertEqual(snapshot["model"], expected_model)
            self.assertNotIn("prompt", snapshot)
            restarted = subprocess.run(
                result.args, input='{"type":"get_commands","id":"probe"}\n',
                text=True, capture_output=True, timeout=30, cwd=directory, env=environment,
            )
            self.assertEqual(restarted.returncode, 0, restarted.stderr)
            next_snapshot = json.loads(status.read_text())
            self.assertGreater(next_snapshot["sequence"], snapshot["sequence"],
                               "Reload/reinitialization must not reset the accepted event sequence")


class GuardTest(unittest.TestCase):
    """The subagent guard, driven by cases written as data (tests/fixtures/guard_probe.ts)."""

    # Fields a single foreground subagent call may set; the guard must block every other one.
    ALLOWED = {"agent", "task", "async", "model", "cwd", "worktree"}
    VALID = {"agent": "reviewer", "task": "review", "async": False, "model": "$MODEL", "cwd": "$CWD"}

    def probe(self, cases):
        """Run pi with the guard probe; return (schema, {case name: result})."""
        if not shutil.which("pi"):
            self.skipTest("pi is not installed")
        root = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory(prefix="pi-guard-test-") as directory:
            PiExtensionTest.configure_agent(self, directory, root)
            case_file, out = Path(directory) / "cases.json", Path(directory) / "out.json"
            case_file.write_text(json.dumps(cases))
            result = subprocess.run(
                ["pi", "--mode", "rpc", "--offline", "-na", "-ne", "-ns", "-np",
                 "--no-mcp", "--no-session", "-e", str(root / "tests/fixtures/guard_probe.ts")],
                input='{"type":"get_commands","id":"probe"}\n', capture_output=True, text=True, timeout=30,
                cwd=directory, env={**os.environ, "PI_CODING_AGENT_DIR": directory, "PROBE_CASES": str(case_file),
                                   "PROBE_OUT": str(out), "NVIM_PI_STATUS": str(Path(directory) / "status.json"),
                                   "NVIM_PI_RUN": "guard"},
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(out.exists(), result.stdout + result.stderr)
            data = json.loads(out.read_text())
            return data["schema"], {item["name"]: item for item in data["results"]}

    def assert_verdicts(self, cases):
        _, results = self.probe(cases)
        wrong = {case["name"]: results[case["name"]] for case in cases
                 if results[case["name"]]["verdict"] != case["expect"]}
        self.assertEqual(wrong, {}, "Guard verdicts differ from the expected ones")

    def test_known_cases(self):
        valid = self.VALID
        self.assert_verdicts([
            {"name": "valid call", "input": valid, "expect": "allow"},
            {"name": "async missing", "input": {**valid, "async": None}, "expect": "block"},
            {"name": "async true", "input": {**valid, "async": True}, "expect": "block"},
            {"name": "inherited model", "input": {**valid, "model": "inherit"}, "expect": "block"},
            {"name": "other model", "input": {**valid, "model": "other/model"}, "expect": "block"},
            {"name": "other cwd", "input": {**valid, "cwd": "/different/worktree"}, "expect": "block"},
            {"name": "managed worktree", "input": {**valid, "worktree": True}, "expect": "block"},
            {"name": "launch tool", "input": valid, "tool": "subagent_launch", "expect": "block"},
        ])

    def test_blocks_every_schema_field_not_allowed(self):
        schema, _ = self.probe([])
        sample = "x"
        cases = [{"name": "top-level " + key, "input": {**self.VALID, key: sample}, "expect": "block"}
                 for key in schema["top"] if key not in self.ALLOWED | {"options"}]
        cases += [{"name": "options." + key, "input": {**self.VALID, "options": {key: sample}}, "expect": "block"}
                  for key in schema["options"]]
        self.assertGreater(len(cases), 10, "The schema must list the tool's fields")
        self.assert_verdicts(cases)


if __name__ == "__main__":
    unittest.main()
