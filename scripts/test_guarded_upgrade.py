import unittest

from guarded_upgrade import (
    ac_safe,
    deploy_conflict,
    failed_units_regressed,
    idle_safe,
    load_idle_report,
    may_activate,
    promotion_safe,
    rollback_target,
    runners_safe,
    session_regressed,
    should_start,
    user_sessions,
)
from check_edge_promotion import promoted


class GuardedUpgradeFixtures(unittest.TestCase):
    def test_promotion_evidence_stale_or_mismatched(self):
        self.assertFalse(promotion_safe("abc", "def", "abc", "success", "main", 1, 1))
        self.assertFalse(promotion_safe("abc", "abc", "def", "success", "main", 1, 1))
        self.assertFalse(promotion_safe("abc", "abc", "abc", "success", "main", 1, 2))
        self.assertTrue(promotion_safe("abc", "abc", "abc", "success", "main", 2, 2))
        run = {
            "id": 7,
            "head_branch": "main",
            "status": "completed",
            "conclusion": "success",
            "event": "schedule",
            "run_attempt": 2,
        }
        self.assertFalse(
            promoted("abc", [run], {7: [{"candidate_sha": "def", "run_attempt": 2}]})
        )
        self.assertFalse(
            promoted("abc", [run], {7: [{"candidate_sha": "abc", "run_attempt": 1}]})
        )
        self.assertTrue(
            promoted("abc", [run], {7: [{"candidate_sha": "abc", "run_attempt": 2}]})
        )

    def test_busy_or_missing_runners(self):
        expected = {
            "p620-nixarchy",
            "p620-nixarchy-2",
            "p620-nixarchy-3",
            "p620-nixarchy-4",
        }
        idle = [{"name": name, "status": "online", "busy": False} for name in expected]
        self.assertTrue(runners_safe(idle, expected))
        self.assertFalse(runners_safe(idle[:-1], expected))
        self.assertFalse(runners_safe([{**idle[0], "busy": True}, *idle[1:]], expected))

    def test_api_errors(self):
        self.assertFalse(runners_safe(None, {"p620-nixarchy"}))
        self.assertFalse(promotion_safe(None, "abc", "abc", "success", "main", 1, 1))

    def test_idle_report_written_by_another_user_is_ignored(self):
        import os
        import tempfile
        from pathlib import Path

        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "1000"
            path.write_text('{"session": "4", "status": "idle"}')
            self.assertEqual(load_idle_report(path, os.getuid())["status"], "idle")
            self.assertEqual(load_idle_report(path, os.getuid() + 1), {})
            self.assertEqual(load_idle_report(Path(d) / "missing", os.getuid()), {})
            path.write_text("not json")
            self.assertEqual(load_idle_report(path, os.getuid()), {})

    def test_idle_resume_and_stale_session(self):
        self.assertTrue(idle_safe("seat-1", "seat-1", "idle", 100, 110))
        self.assertFalse(idle_safe("seat-1", "seat-1", "active", 100, 110))
        self.assertFalse(idle_safe("seat-1", "seat-2", "idle", 100, 110))
        self.assertFalse(idle_safe("seat-1", "seat-1", "idle", 100, 1000))

    def test_ac_loss(self):
        self.assertTrue(ac_safe("1"))
        self.assertFalse(ac_safe("0"))
        self.assertFalse(ac_safe(None))

    def test_duplicate_invocations(self):
        self.assertTrue(should_start(False, False))
        self.assertFalse(should_start(True, False))
        self.assertFalse(should_start(False, True))

    def test_baseline_vs_new_failed_units(self):
        self.assertFalse(failed_units_regressed({"old.service"}, {"old.service"}))
        self.assertTrue(
            failed_units_regressed({"old.service"}, {"old.service", "new.service"})
        )

    def test_activation_needs_its_flag_on_every_host(self):
        self.assertFalse(may_activate(False))
        self.assertFalse(may_activate(None))
        self.assertFalse(may_activate("true"))
        self.assertTrue(may_activate(True))

    def test_manual_deploy_blocks_activation(self):
        own = {100, 101}
        rebuild = "nixos-" + "rebuild"
        stc = "/nix/store/x-nixos-system/bin/switch-to-" + "configuration"
        ng = [
            "/nix/store/p-python3/bin/python3",
            "/nix/store/r/bin/" + rebuild,
            "switch",
        ]
        self.assertTrue(
            deploy_conflict([(200, [rebuild, "switch", "--flake", ".#razer"])], own)
        )
        self.assertTrue(deploy_conflict([(201, [stc, "switch"])], own))
        self.assertTrue(
            deploy_conflict([(202, ["nh", "--verbose", "os", "switch"])], own)
        )
        self.assertTrue(deploy_conflict([(203, ng)], own))
        # Its own ancestry, and processes that only mention a switch, never block.
        self.assertFalse(deploy_conflict([(100, [stc, "switch"])], own))
        self.assertFalse(deploy_conflict([(204, ["man", rebuild])], own))
        self.assertFalse(
            deploy_conflict([(205, ["vim", "notes-on-" + rebuild + ".md"])], own)
        )
        self.assertFalse(deploy_conflict([(206, [])], own))
        # nixpkgs' .X-wrapped names, and interpreter flags before the script.
        self.assertTrue(
            deploy_conflict([(207, ["/nix/store/n/bin/.nh-wrapped", "os"])], own)
        )
        self.assertTrue(
            deploy_conflict(
                [
                    (
                        208,
                        ["perl", "-w", "/nix/store/s/bin/switch-to-" + "configuration"],
                    )
                ],
                own,
            )
        )
        self.assertTrue(
            deploy_conflict([(209, ["/usr/bin/env", rebuild, "switch"])], own)
        )

    def test_people_not_the_greeter_count_as_sessions(self):
        props = {
            "1": {"Class": "greeter", "State": "active", "Type": "wayland"},
            "2": {"Class": "user", "State": "active", "Type": "wayland"},
            "3": {"Class": "user", "State": "online", "Type": "tty"},
            "4": {"Class": "user", "State": "closing", "Type": "wayland"},
        }
        self.assertEqual(user_sessions(props), {"2", "3"})
        self.assertEqual(user_sessions({"1": props["1"]}), set())

    def test_session_must_survive_the_switch(self):
        self.assertTrue(session_regressed({"3"}, set()))
        # A session that crashed and was replaced by a new login is still lost.
        self.assertTrue(session_regressed({"3"}, {"4"}))
        self.assertFalse(session_regressed({"3"}, {"3"}))
        self.assertFalse(session_regressed({"3"}, {"3", "4"}))
        self.assertFalse(session_regressed(set(), {"4"}))

    def test_deploy_lock_refuses_when_a_manual_hold_has_it(self):
        import fcntl
        import tempfile
        from pathlib import Path

        import guarded_upgrade

        with tempfile.TemporaryDirectory() as tmp:
            lock = Path(tmp) / "nixos-deploy.lock"
            original = guarded_upgrade.DEPLOY_LOCK
            guarded_upgrade.DEPLOY_LOCK = lock
            try:
                with guarded_upgrade.deploy_lock():
                    pass  # free: taken and released
                with lock.open("a") as held:
                    fcntl.flock(held, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    with self.assertRaises(RuntimeError):
                        with guarded_upgrade.deploy_lock():
                            pass
            finally:
                guarded_upgrade.DEPLOY_LOCK = original

    def test_rollback_target_selection(self):
        old = "/nix/store/" + "a" * 32 + "-old"
        self.assertEqual(rollback_target(old, 12), (old, 12))
        with self.assertRaises(ValueError):
            rollback_target(old, None)


if __name__ == "__main__":
    unittest.main()
