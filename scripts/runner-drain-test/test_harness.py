import importlib.util
import os
import tempfile
import unittest
from pathlib import Path

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

    def test_guarded_upgrade_env_names_exist_in_the_script(self):
        env = run_test.discover_guarded_upgrade_env(
            repo="example/drain-test", drain_timeout=25, drain_poll=2
        )
        script = run_test.GUARDED_UPGRADE_SCRIPT.read_text()
        for key in env:
            if key.startswith("GUARDED_"):
                self.assertIn(
                    f'"{key}"', script, f"{key} is not read by guarded_upgrade.py"
                )
        self.assertEqual(env["GUARDED_WINDOW"], "0-24")
        self.assertEqual(env["GUARDED_DRAIN_TIMEOUT"], "25")

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
