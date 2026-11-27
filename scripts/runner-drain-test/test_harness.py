import importlib.util
import json
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
        self.assertEqual(env["GUARDED_POLL"], "2")

    def test_guest_launcher_does_not_rewrite_guarded_upgrade_ast(self):
        self.assertNotIn("NodeTransformer", run_test.GUEST_RUNNER_LAUNCHER)
        self.assertNotIn(
            "RUNNER_DRAIN_TEST_DEADLINE_OVERRIDE", run_test.GUEST_RUNNER_LAUNCHER
        )
        self.assertNotIn(
            "RUNNER_DRAIN_TEST_POLL_OVERRIDE", run_test.GUEST_RUNNER_LAUNCHER
        )
        # Boundary hold happens in-process at the STATE/drain journal write (after the
        # in-lock gate passes and before drain/request is written), not in a loginctl wrapper.
        self.assertIn("hold-boundary", run_test.GUEST_RUNNER_LAUNCHER)
        self.assertIn("boundary-reached", run_test.GUEST_RUNNER_LAUNCHER)
        self.assertFalse(hasattr(run_test, "GUEST_LOGINCTL_WRAPPER"))

    def test_vm_nix_has_no_dead_github_runner_drain_overlay(self):
        vm_nix = run_test.VM_NIX_FILE.read_text()
        self.assertNotIn("github-runner-drain =", vm_nix)

    def test_collect_condition_skips_requires_condition_result_no_while_closed(self):
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
        # Newer ConditionTimestampMonotonic with ConditionResult="yes" must NOT count as skipped.
        during_yes = {
            "units": {
                u: {
                    "ConditionTimestampMonotonic": "250",
                    "ConditionTimestamp": "Fri 2026-11-27 13:00:00 UTC",
                    "ConditionResult": "yes",
                    "ActiveState": "active",
                }
                for u in run_test.RUNNER_UNITS
            },
            "state": {"runners_closed": True},
        }
        skips_yes = harness.collect_condition_skips(before, [during_yes])
        for u in run_test.RUNNER_UNITS:
            self.assertFalse(skips_yes[u]["skipped"])
            self.assertEqual(skips_yes[u]["observations"], [])

        # ConditionResult="no" while runners_closed is False must NOT count either.
        during_open_no = {
            "units": {
                u: {
                    "ConditionTimestampMonotonic": "250",
                    "ConditionTimestamp": "Fri 2026-11-27 13:00:00 UTC",
                    "ConditionResult": "no",
                    "ActiveState": "inactive",
                }
                for u in run_test.RUNNER_UNITS
            },
            "state": {"runners_closed": False},
        }
        skips_open = harness.collect_condition_skips(before, [during_open_no])
        for u in run_test.RUNNER_UNITS:
            self.assertFalse(skips_open[u]["skipped"])

        # Explicit ConditionResult="no" while runners_closed is True counts as skipped.
        during_no = {
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
        skips = harness.collect_condition_skips(before, [during_no])
        for u in run_test.RUNNER_UNITS:
            self.assertTrue(skips[u]["skipped"])
            self.assertEqual(skips[u]["observations"][0]["ConditionResult"], "no")

    def test_summarize_attempt_dir_independent_per_attempt_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            cdir = Path(tmp)
            key = "b-nonce123"
            (cdir / f"{key}.attempt.101-1-p620-nixarchy-111.started.json").write_text(
                json.dumps(
                    {
                        "event": "started",
                        "scenario": "b",
                        "nonce": "nonce123",
                        "run_id": "101",
                        "attempt": "1",
                        "runner": "p620-nixarchy",
                        "ts": 1000,
                    }
                )
            )
            (cdir / f"{key}.attempt.101-1-p620-nixarchy-111.completed.json").write_text(
                json.dumps(
                    {
                        "event": "completed",
                        "scenario": "b",
                        "nonce": "nonce123",
                        "run_id": "101",
                        "attempt": "1",
                        "runner": "p620-nixarchy",
                        "started_at": 1000,
                        "ts": 1005,
                    }
                )
            )
            # A duplicate attempt on another runner writes its own independent files.
            (cdir / f"{key}.attempt.101-2-p620-nixarchy-2-222.started.json").write_text(
                json.dumps(
                    {
                        "event": "started",
                        "scenario": "b",
                        "nonce": "nonce123",
                        "run_id": "101",
                        "attempt": "2",
                        "runner": "p620-nixarchy-2",
                        "ts": 1002,
                    }
                )
            )
            summary = run_test.summarize_attempt_dir(cdir, "b", "nonce123")
            self.assertEqual(summary["started"], 2)
            self.assertEqual(summary["completed"], 1)
            self.assertEqual(summary["run_ids"], ["101"])
            self.assertEqual(len(summary["events"]), 3)

    def test_record_and_verify_queued_during_closed_window(self):
        transitions = []
        run_test.record_job_transition(
            transitions,
            [
                {
                    "id": 555,
                    "run_id": 900,
                    "name": "drain-test",
                    "status": "queued",
                    "conclusion": None,
                    "created_at": "2026-11-27T13:00:05Z",
                    "started_at": None,
                    "completed_at": None,
                }
            ],
            observed_at=1005.0,
        )
        # Same state repeated does not duplicate transition.
        run_test.record_job_transition(
            transitions,
            [{"id": 555, "run_id": 900, "status": "queued", "conclusion": None}],
            observed_at=1010.0,
        )
        self.assertEqual(len(transitions), 1)
        run_test.record_job_transition(
            transitions,
            [
                {
                    "id": 555,
                    "run_id": 900,
                    "status": "in_progress",
                    "conclusion": None,
                    "started_at": "2026-11-27T13:00:25Z",
                }
            ],
            observed_at=1025.0,
        )
        run_test.record_job_transition(
            transitions,
            [
                {
                    "id": 555,
                    "run_id": 900,
                    "status": "completed",
                    "conclusion": "success",
                    "started_at": "2026-11-27T13:00:25Z",
                    "completed_at": "2026-11-27T13:00:30Z",
                }
            ],
            observed_at=1030.0,
        )
        self.assertEqual(len(transitions), 3)
        self.assertTrue(
            run_test.verify_queued_during_closed_window(
                transitions, admission_closed_at=1000.0, reopened_at=1020.0
            )
        )
        # If it started before reopen (e.g. reopened_at=1028), verification fails.
        self.assertFalse(
            run_test.verify_queued_during_closed_window(
                transitions, admission_closed_at=1000.0, reopened_at=1028.0
            )
        )

    def test_classify_boundary_runs(self):
        pre_events = [
            {"event": "started", "ts": 1002},
            {"event": "completed", "ts": 1015},
        ]
        post_events = [
            {"event": "started", "ts": 1032},
            {"event": "completed", "ts": 1038},
        ]
        post_transitions = [
            {
                "job_id": 77,
                "status": "queued",
                "conclusion": None,
                "observed_at": 1004.0,
            },
            {
                "job_id": 77,
                "status": "in_progress",
                "conclusion": None,
                "observed_at": 1032.0,
            },
            {
                "job_id": 77,
                "status": "completed",
                "conclusion": "success",
                "observed_at": 1038.0,
            },
        ]
        verdict = run_test.classify_boundary_runs(
            pre_run_events=pre_events,
            post_run_events=post_events,
            post_transitions=post_transitions,
            boundary_closed_at=1003.0,
            switch_at=1020.0,
            reopened_at=1030.0,
        )
        self.assertTrue(verdict["ok"])
        self.assertEqual(verdict["pre_boundary_side"], "before_switch")
        self.assertEqual(verdict["post_boundary_side"], "after_reopen")


if __name__ == "__main__":
    unittest.main()
