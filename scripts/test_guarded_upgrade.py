import unittest

from guarded_upgrade import (
    ac_safe,
    failed_units_regressed,
    idle_safe,
    may_activate,
    promotion_safe,
    rollback_target,
    runners_safe,
    should_start,
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

    def test_rollback_target_selection(self):
        old = "/nix/store/" + "a" * 32 + "-old"
        self.assertEqual(rollback_target(old, 12), (old, 12))
        with self.assertRaises(ValueError):
            rollback_target(old, None)


if __name__ == "__main__":
    unittest.main()
