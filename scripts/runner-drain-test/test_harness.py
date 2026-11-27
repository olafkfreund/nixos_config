import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest


HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("run_test", HERE / "run-test.py")
run_test = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(run_test)


class RunnerDrainHarnessTests(unittest.TestCase):
    def test_normalize_repo(self):
        self.assertEqual(
            run_test.normalize_repo("olafkfreund/drain-disp"),
            "olafkfreund/drain-disp",
        )
        self.assertEqual(
            run_test.normalize_repo("https://github.com/olafkfreund/drain-disp.git"),
            "olafkfreund/drain-disp",
        )
        self.assertEqual(
            run_test.normalize_repo("github:olafkfreund/drain-disp/"),
            "olafkfreund/drain-disp",
        )
        with self.assertRaises(ValueError):
            run_test.normalize_repo("just-one-part")

    def test_refuses_agenix_secret_path_by_default(self):
        with self.assertRaises(RuntimeError):
            run_test.resolve_token_from_env(
                token_file="/run/agenix/api-github-token",
                allow_agenix=False,
            )

    def test_reads_disposable_token_from_file_or_env(self):
        with tempfile.TemporaryDirectory() as tmp:
            tfile = Path(tmp) / "disposable-token"
            tfile.write_text("ghp_test_disposable_token_value\n")
            self.assertEqual(
                run_test.resolve_token_from_env(token_file=str(tfile)),
                "ghp_test_disposable_token_value",
            )
        old = os.environ.get("RUNNER_DRAIN_TEST_TOKEN")
        try:
            os.environ["RUNNER_DRAIN_TEST_TOKEN"] = "ghp_from_env"
            self.assertEqual(run_test.resolve_token_from_env(), "ghp_from_env")
        finally:
            if old is None:
                os.environ.pop("RUNNER_DRAIN_TEST_TOKEN", None)
            else:
                os.environ["RUNNER_DRAIN_TEST_TOKEN"] = old

    def test_discover_guarded_upgrade_env_adapts_to_custom_var_names_and_shapes(self):
        sample_script = """
import json
import os

REPO = os.environ.get("CUSTOM_FLAKE_REPO", "github:olafkfreund/nixos_config")
GIT_REMOTE = os.environ.get("CUSTOM_GIT_URL", "https://github.com/olafkfreund/nixos_config.git")
ISSUES_REPO = os.environ.get("CUSTOM_ISSUES_SHORT", "nixos_config")
ACTIONS_REPO = os.environ.get("CUSTOM_ACTIONS_FULL", "olafkfreund/nixarchy")
UNIT_PREFIX = os.environ.get("CUSTOM_UNIT_SHORT", "nixarchy")
FULL_UNIT_PREFIX = os.environ.get("CUSTOM_UNIT_FULL", "github-runner-nixarchy")
NAME_PREFIX = os.environ.get("CUSTOM_RUNNER_PREFIX", "p620-nixarchy")
WORKFLOWS_COLON = os.environ.get(
    "CUSTOM_WORKFLOWS_STR", "install-check.yml:install,omarchy-edge.yml:verify"
)
WORKFLOWS_JSON = json.loads(
    os.environ.get("CUSTOM_WORKFLOWS_JSON", '[["install-check.yml", "install"]]')
)
WINDOW_HOUR = int(os.environ.get("CUSTOM_WINDOW_HOUR", "4"))
BUS_ROOM = os.environ.get("CUSTOM_BUS_ROOM", "#agents:freundcloud.org.uk")
"""
        env = run_test.discover_guarded_upgrade_env(
            source_text=sample_script,
            repo="olafkfreund/disp-drain-repo",
            runner_unit_prefix="github-runner-nixarchy",
            runner_name_prefix="p620-nixarchy",
            workflow_file="drain-test.yml",
            job_name="drain-test",
            window_hour=14,
            bus_room="#runner-drain-test:localhost",
            token_file="/run/runner-drain-test/github-token",
            drain_timeout=25,
            drain_poll=2,
        )
        self.assertEqual(env["CUSTOM_FLAKE_REPO"], "github:olafkfreund/disp-drain-repo")
        self.assertEqual(
            env["CUSTOM_GIT_URL"],
            "https://github.com/olafkfreund/disp-drain-repo.git",
        )
        self.assertEqual(env["CUSTOM_ISSUES_SHORT"], "disp-drain-repo")
        self.assertEqual(env["CUSTOM_ACTIONS_FULL"], "olafkfreund/disp-drain-repo")
        self.assertEqual(env["CUSTOM_UNIT_SHORT"], "nixarchy")
        self.assertEqual(env["CUSTOM_UNIT_FULL"], "github-runner-nixarchy")
        self.assertEqual(env["CUSTOM_RUNNER_PREFIX"], "p620-nixarchy")
        self.assertEqual(env["CUSTOM_WORKFLOWS_STR"], "drain-test.yml:drain-test")
        self.assertEqual(
            json.loads(env["CUSTOM_WORKFLOWS_JSON"]),
            [["drain-test.yml", "drain-test"]],
        )
        self.assertEqual(env["CUSTOM_WINDOW_HOUR"], "14")
        self.assertEqual(env["CUSTOM_BUS_ROOM"], "#runner-drain-test:localhost")

    def test_collect_condition_skips(self):
        harness = run_test.VMHarness(
            repo="olafkfreund/disp",
            token="dummy",
            label="drain-test",
            workdir="/tmp",
        )
        before = {
            "units": {
                u: {
                    "ConditionTimestampMonotonic": "100",
                    "ConditionResult": "yes",
                    "ActiveState": "active",
                }
                for u in run_test.RUNNER_UNITS
            },
            "state": {"runners_closed": False},
        }
        during = {
            "units": {
                u: {
                    "ConditionTimestampMonotonic": "250",
                    "ConditionTimestamp": "Fri 2026-11-27 13:00:00 UTC",
                    "ConditionResult": "no",
                    "ActiveState": "inactive",
                }
                for u in run_test.RUNNER_UNITS
            },
            "state": {"runners_closed": True},
        }
        skips = harness.collect_condition_skips(before, [during])
        for u in run_test.RUNNER_UNITS:
            self.assertTrue(skips[u]["skipped"])
            self.assertEqual(skips[u]["observations"][0]["ConditionResult"], "no")


if __name__ == "__main__":
    unittest.main()
