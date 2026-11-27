import fcntl
import importlib.util
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import guarded_upgrade as gu
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

REAL_GATE = gu.gate


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

    def test_ssh_without_a_tty_is_not_a_person(self):
        props = {
            "4": {
                "Class": "user",
                "State": "active",
                "Type": "wayland",
                "Service": "sddm",
                "TTY": "tty2",
            },
            "306": {
                "Class": "user",
                "State": "active",
                "Type": "tty",
                "Service": "sshd",
                "TTY": "",
            },
            "610": {
                "Class": "user",
                "State": "active",
                "Type": "tty",
                "Service": "sshd",
            },
            "7": {
                "Class": "user",
                "State": "active",
                "Type": "tty",
                "Service": "sshd",
                "TTY": "pts/0",
            },
            "8": {
                "Class": "user",
                "State": "active",
                "Type": "tty",
                "Service": "login",
                "TTY": "",
            },
        }
        self.assertEqual(user_sessions(props), {"4", "7", "8"})

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


SHA = "a" * 40
OLD = "/nix/store/" + "0" * 32 + "-old"
NEW = "/nix/store/" + "1" * 32 + "-new"
UNITS = [gu.runner_unit(s) for s in gu.SUFFIXES]


class FakeHost:
    """systemd, the four listeners, GitHub and the clock, in memory and a temp dir."""

    def __init__(self, root):
        self.state = root / "state"
        self.runners = root / "runners"
        self.cgroups = root / "cgroup"
        self.state.mkdir()
        for suffix in gu.SUFFIXES:
            (self.runners / ("nixarchy" + suffix)).mkdir(parents=True)
        self.units = {u: {"ActiveState": "active", "InvocationID": u} for u in UNITS}
        # "exit" drains, "busy" keeps its job, "silent" never acknowledges.
        self.behaviour = dict.fromkeys(UNITS, "exit")
        self.now = 1000.0
        self.calls = []
        self.started = []
        self.offline = set()
        self.invocations = 0
        self.current = OLD
        self.on_sleep = lambda: None

    def drain(self, unit):
        suffix = gu.SUFFIXES[UNITS.index(unit)]
        return self.runners / ("nixarchy" + suffix) / "drain"

    def ack(self, unit, **ack):
        self.drain(unit).mkdir(exist_ok=True)
        (self.drain(unit) / "ack").write_text(json.dumps(ack))

    def listen(self):
        for unit, props in self.units.items():
            request = self.drain(unit) / "request"
            if props["ActiveState"] != "active" or not request.exists():
                continue
            if self.behaviour[unit] == "silent":
                continue
            busy = self.behaviour[unit] == "busy"
            self.ack(
                unit,
                id=json.loads(request.read_text())["id"],
                invocation=props["InvocationID"],
                state="draining" if busy else "exited-idle",
            )
            if not busy:
                props["ActiveState"] = "inactive"

    def sleep(self, seconds):
        self.now += seconds
        self.on_sleep()
        self.listen()

    def run(self, *args, check=True, timeout=None):
        self.calls.append(args)
        if args[:2] == ("systemctl", "show"):
            return "\n".join(f"{k}={v}" for k, v in self.units[args[2]].items())
        if args[:2] == ("systemctl", "start"):
            assert timeout, "an unbounded start"
            self.started.append(args[2:])
            for unit in args[2:]:
                closed = (self.state / "runners-closed").exists()
                if not closed and self.units[unit]["ActiveState"] != "active":
                    self.invocations += 1
                    self.units[unit] = {
                        "ActiveState": "active",
                        "InvocationID": f"new-{self.invocations}",
                    }
            return ""
        raise AssertionError(f"unexpected command {args}")

    def github(self, path, method="GET", body=None):
        return {
            "runners": [
                {
                    "name": gu.RUNNER_NAME + suffix,
                    "status": "online"
                    if self.units[unit]["ActiveState"] == "active"
                    and unit not in self.offline
                    else "offline",
                    "busy": True,
                }
                for suffix, unit in zip(gu.SUFFIXES, UNITS)
            ]
        }


class DrainCase(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        self.host = host = FakeHost(root)
        self.logs = []
        self.gates = []
        self.patch(
            STATE=host.state,
            RUNNER_STATE=host.runners,
            CGROUP_ROOT=host.cgroups,
            DEPLOY_LOCK=root / "deploy.lock",
            run=host.run,
            github=host.github,
            log=self.logs.append,
            resolve_main=lambda: SHA,
            gate=lambda name, runners=True: self.gates.append((name, runners)),
            is_current=lambda candidate: candidate == host.current,
        )
        self.patch_object(gu.time, "sleep", host.sleep)
        self.patch_object(gu.time, "time", lambda: host.now)

    def tearDown(self):
        # Defer never stops a unit, and neither does anything else.
        for call in self.host.calls:
            if call[0] == "systemctl":
                self.assertIn(call[1], ("show", "start"), call)

    def patch_object(self, target, name, value):
        patcher = mock.patch.object(target, name, value)
        patcher.start()
        self.addCleanup(patcher.stop)

    def patch(self, **values):
        for name, value in values.items():
            self.patch_object(gu, name, value)

    def exists(self, name):
        return (self.host.state / name).exists()

    def requests(self):
        return [u for u in UNITS if (self.host.drain(u) / "request").exists()]

    def fake_activate(self, fail=None):
        """Stands in for activate(); records what was true while it ran."""
        seen = {}

        def activate(host, sha, candidate):
            seen["phase"] = gu.read("drain")["phase"]
            seen["closed"] = self.exists("runners-closed")
            seen["states"] = {p["ActiveState"] for p in self.host.units.values()}
            if fail == "rolled-back":
                raise gu.RolledBack("verification failed")
            if fail == "unfinished":
                gu.save("transaction", {"sha": sha})
                raise RuntimeError("rollback switch failed")
            if fail == "before":
                raise RuntimeError("running and boot default generations differ")
            self.host.current = candidate

        self.patch(activate=activate)
        return seen

    def assert_deferred(self, started):
        self.assertFalse(self.exists("drain"))
        self.assertFalse(self.exists("runners-closed"))
        self.assertFalse(self.exists("verified"))
        self.assertEqual(self.requests(), [])
        self.assertEqual(self.host.started, started)
        self.assertTrue(
            any(m.startswith("deferred: drain incomplete") for m in self.logs)
        )


class DrainAndSwitch(DrainCase):
    def test_success_switches_closed_and_publishes_only_after_the_reopen(self):
        seen = self.fake_activate()
        gu.save("verified", {"sha": "stale"})
        published_early = []
        self.host.offline = {UNITS[0]}

        def come_online():
            if self.host.started:
                published_early.append(self.exists("verified"))
                self.host.offline = set()

        self.host.on_sleep = come_online
        self.assertTrue(gu.drained_activate(SHA, NEW))
        self.assertEqual(
            seen, {"phase": "switching", "closed": True, "states": {"inactive"}}
        )
        self.assertEqual(published_early, [False])
        self.assertEqual(gu.read("verified"), {"sha": SHA, "candidate": NEW})
        self.assertFalse(self.exists("drain"))
        self.assertFalse(self.exists("runners-closed"))
        self.assertEqual(self.requests(), [])
        self.assertEqual(self.gates, [("p620", False)])

    def test_journal_is_written_and_canary_gone_before_the_marker(self):
        self.fake_activate()
        gu.save("verified", {"sha": "stale"})
        seen = []

        def touch(path, *args, **kwargs):
            seen.append((path.name, gu.read("drain")["phase"], self.exists("verified")))
            raise OSError("disk full")

        self.patch_object(gu.Path, "touch", touch)
        self.assertFalse(gu.drained_activate(SHA, NEW))
        self.assertEqual(seen, [("runners-closed", "draining", False)])

    def test_request_file_contract(self):
        gu.write_request("", "abc")
        request = self.host.drain(UNITS[0]) / "request"
        self.assertEqual(json.loads(request.read_text()), {"id": "abc"})
        self.assertEqual(request.stat().st_mode & 0o777, 0o644)
        self.assertEqual(os.listdir(request.parent), ["request"])

    def test_a_symlinked_drain_directory_is_refused(self):
        elsewhere = self.host.state / "elsewhere"
        elsewhere.mkdir()
        (elsewhere / "ack").write_text('{"id": "abc"}')
        self.host.drain(UNITS[0]).symlink_to(elsewhere)
        with self.assertRaises(OSError):
            gu.write_request("", "abc")
        self.assertEqual(os.listdir(elsewhere), ["ack"])
        self.assertEqual(gu.read_ack(""), {})

    def test_a_planted_fifo_or_junk_ack_reads_as_none(self):
        self.host.drain(UNITS[0]).mkdir()
        ack = self.host.drain(UNITS[0]) / "ack"
        os.mkfifo(ack)
        self.assertEqual(gu.read_ack(""), {})
        ack.unlink()
        for junk in ("not json", "[1]"):
            ack.write_text(junk)
            self.assertEqual(gu.read_ack(""), {})

    def test_drained_needs_every_condition(self):
        unit = UNITS[0]
        good = {"id": "r", "invocation": unit, "state": "exited-after-job"}
        self.host.units[unit]["ActiveState"] = "inactive"
        self.host.ack(unit, **good)
        self.assertTrue(gu.runner_drained("", "r", unit))
        self.assertFalse(gu.runner_drained("", "r", ""))
        self.host.ack(unit, **{**good, "invocation": ""})
        self.assertFalse(gu.runner_drained("", "r", ""))
        self.host.ack(unit, **good)
        for wrong in (
            {"id": "other"},
            {"invocation": "other"},
            {"state": "draining"},
            {"state": "cancelled"},
        ):
            self.host.ack(unit, **{**good, **wrong})
            self.assertFalse(gu.runner_drained("", "r", unit), wrong)
        self.host.ack(unit, **good)
        for state in ("active", "deactivating", "failed"):
            self.host.units[unit]["ActiveState"] = state
            self.assertFalse(gu.runner_drained("", "r", unit), state)
        self.host.units[unit].update(ActiveState="inactive", ControlGroup="/s/u")
        events = self.host.cgroups / "s/u/cgroup.events"
        events.parent.mkdir(parents=True)
        events.write_text("populated 1\nfrozen 0\n")
        self.assertFalse(gu.runner_drained("", "r", unit))
        events.write_text("populated 0\nfrozen 0\n")
        self.assertTrue(gu.runner_drained("", "r", unit))

    def test_withheld_acknowledgement_defers_without_touching_that_unit(self):
        seen = self.fake_activate()
        self.host.behaviour[UNITS[1]] = "silent"
        self.assertFalse(gu.drained_activate(SHA, NEW))
        self.assertEqual(seen, {})
        self.assert_deferred([(UNITS[0], UNITS[2], UNITS[3])])
        self.assertEqual(self.host.units[UNITS[1]]["InvocationID"], UNITS[1])

    def test_a_job_past_the_deadline_defers(self):
        seen = self.fake_activate()
        self.host.behaviour[UNITS[3]] = "busy"
        self.assertFalse(gu.drained_activate(SHA, NEW))
        self.assertEqual(seen, {})
        self.assertGreaterEqual(self.host.now - 1000, gu.DRAIN_TIMEOUT)
        self.assertLess(self.host.now - 1000, gu.DRAIN_TIMEOUT + 2 * gu.POLL)
        self.assert_deferred([tuple(UNITS[:3])])

    def test_a_job_finishing_before_the_deadline_is_waited_for(self):
        self.fake_activate()
        self.host.behaviour[UNITS[3]] = "busy"

        def finish():
            if self.host.now > 1000 + gu.DRAIN_TIMEOUT - 60:
                self.host.behaviour[UNITS[3]] = "exit"

        self.host.on_sleep = finish
        self.assertTrue(gu.drained_activate(SHA, NEW))

    def test_defer_waits_for_a_listener_that_is_already_exiting(self):
        unit = UNITS[0]
        self.host.units[unit]["ActiveState"] = "deactivating"
        self.host.on_sleep = lambda: self.host.units[unit].update(
            ActiveState="inactive"
        )
        gu.defer({"request": "r"}, "why")
        self.assertEqual(self.host.started, [(unit,)])

    def test_defer_with_every_unit_running_starts_nothing(self):
        gu.defer({"request": "r"}, "why")
        self.assert_deferred([])

    def test_gate_failing_after_the_drain_defers(self):
        seen = self.fake_activate()

        def gate(name, runners=True):
            raise RuntimeError("outside the activation window")

        self.patch(gate=gate)
        self.assertFalse(gu.drained_activate(SHA, NEW))
        self.assertEqual(seen, {})
        self.assert_deferred([tuple(UNITS)])

    def test_main_advancing_during_the_drain_defers(self):
        seen = self.fake_activate()
        self.patch(resolve_main=lambda: "b" * 40)
        self.assertFalse(gu.drained_activate(SHA, NEW))
        self.assertEqual(seen, {})
        self.assert_deferred([tuple(UNITS)])

    def test_a_failure_before_the_transaction_defers(self):
        self.fake_activate("before")
        self.assertFalse(gu.drained_activate(SHA, NEW))
        self.assert_deferred([tuple(UNITS)])

    def test_rollback_reopens_and_publishes_nothing(self):
        self.fake_activate("rolled-back")
        with self.assertRaises(gu.RolledBack):
            gu.drained_activate(SHA, NEW)
        self.assertEqual(self.host.started, [tuple(UNITS)])
        for name in ("drain", "runners-closed", "verified"):
            self.assertFalse(self.exists(name), name)

    def test_an_unfinished_rollback_leaves_the_runners_closed(self):
        self.fake_activate("unfinished")
        with self.assertRaises(RuntimeError):
            gu.drained_activate(SHA, NEW)
        self.assertEqual(gu.read("drain")["phase"], "switching")
        self.assertTrue(self.exists("runners-closed"))
        self.assertEqual(self.host.started, [])
        self.assertEqual(gu.failure_status(RuntimeError()), 1)

    def test_a_runner_that_stays_offline_fails_the_reopen(self):
        self.fake_activate()
        self.host.offline = {UNITS[2]}
        with self.assertRaises(gu.ReopenFailed) as caught:
            gu.drained_activate(SHA, NEW)
        self.assertEqual(gu.read("drain")["phase"], "reopen-failed")
        self.assertFalse(self.exists("verified"))
        self.assertEqual(gu.failure_status(caught.exception), 1)

    def test_ready_needs_a_new_invocation(self):
        previous = {s: gu.runner_unit(s) for s in gu.SUFFIXES}
        with self.assertRaises(RuntimeError):
            gu.wait_ready(previous)
        gu.wait_ready(dict.fromkeys(gu.SUFFIXES, "before"))

    def test_failure_status_without_anything_left_open(self):
        self.assertEqual(gu.failure_status(RuntimeError("busy")), 0)
        self.assertEqual(gu.failure_status(gu.RolledBack("x")), 1)
        for name in ("transaction", "drain", "runners-closed"):
            (self.host.state / name).touch()
            self.assertEqual(gu.failure_status(RuntimeError()), 1, name)
            (self.host.state / name).unlink()


class Recovery(DrainCase):
    """Through main(), with the pause flag set: recovery must come first."""

    def setUp(self):
        super().setUp()
        (self.host.state / "pause").touch()
        self.rolled_back = []

        def rollback(record, why):
            self.assertEqual(self.host.started, [], "reopened before the rollback")
            self.rolled_back.append(record["sha"])
            (self.host.state / "transaction").unlink()

        def gate(*args, **kwargs):
            raise AssertionError("recovery must not depend on a gate")

        self.patch(rollback=rollback, gate=gate)

    def interrupted(self, phase, closed=True):
        for unit in UNITS:
            self.host.units[unit]["ActiveState"] = "inactive"
        if closed:
            (self.host.state / "runners-closed").touch()
        for suffix in gu.SUFFIXES:
            gu.write_request(suffix, "r")
        if phase:
            gu.save(
                "drain",
                {
                    "phase": phase,
                    "sha": SHA,
                    "candidate": NEW,
                    "request": "r",
                    "invocations": {s: gu.runner_unit(s) for s in gu.SUFFIXES},
                },
            )

    def assert_reopened(self):
        self.assertEqual(self.host.started, [tuple(UNITS)])
        self.assertEqual(self.requests(), [])
        self.assertFalse(self.exists("drain"))
        self.assertFalse(self.exists("runners-closed"))

    def test_nothing_to_recover(self):
        self.assertIsNone(gu.recover("p620"))
        self.assertEqual(gu.main("p620", True), 0)
        self.assertEqual(self.host.calls, [])

    def test_draining_defers(self):
        self.interrupted("draining")
        self.assertEqual(gu.main("p620", True), 0)
        self.assert_deferred([tuple(UNITS)])

    def test_switching_with_a_transaction_rolls_back_then_reopens(self):
        self.interrupted("switching")
        gu.save("transaction", {"sha": SHA})
        self.assertEqual(gu.main("p620", True), 1)
        self.assertEqual(self.rolled_back, [SHA])
        self.assert_reopened()
        self.assertFalse(self.exists("verified"))

    def test_switching_without_a_transaction_reopens_without_publishing(self):
        self.interrupted("switching")
        self.host.current = NEW
        self.assertEqual(gu.main("p620", True), 0)
        self.assertEqual(self.rolled_back, [])
        self.assert_reopened()
        self.assertFalse(self.exists("verified"))

    def test_settled_commit_reopens_and_publishes(self):
        self.interrupted("settled-commit")
        self.host.current = NEW
        self.assertEqual(gu.main("p620", True), 0)
        self.assert_reopened()
        self.assertEqual(gu.read("verified"), {"sha": SHA, "candidate": NEW})

    def test_settled_commit_no_longer_running_is_not_published(self):
        self.interrupted("settled-commit")
        self.assertEqual(gu.main("p620", True), 0)
        self.assertFalse(self.exists("verified"))

    def test_settled_rollback_and_reopen_failed_reopen_without_publishing(self):
        for phase in ("settled-rollback", "reopen-failed"):
            self.host.started.clear()
            self.host.current = NEW
            self.interrupted(phase, closed=phase != "reopen-failed")
            self.assertEqual(gu.main("p620", True), 0, phase)
            self.assert_reopened()
            self.assertFalse(self.exists("verified"), phase)

    def test_a_failed_recovery_keeps_the_journal(self):
        self.interrupted("settled-commit")
        self.host.offline = {UNITS[0]}
        with self.assertRaises(gu.ReopenFailed):
            gu.main("p620", True)
        self.assertEqual(gu.read("drain")["phase"], "reopen-failed")

    def test_orphan_marker_is_logged_and_reopened(self):
        self.interrupted(None)
        self.assertEqual(gu.main("p620", True), 0)
        self.assertTrue(any("orphan" in m for m in self.logs))
        self.assert_reopened()

    def test_a_rollback_without_a_journal_reopens_on_p620_only(self):
        for name, starts in (("razer", []), ("p620", [tuple(UNITS)])):
            self.interrupted(None, closed=False)
            gu.save("transaction", {"sha": SHA})
            self.assertEqual(gu.main(name, True), 1)
            self.assertEqual(self.host.started, starts, name)

    def test_recovery_waits_for_the_deploy_lock(self):
        self.interrupted("switching")
        with gu.deploy_lock(), self.assertRaises(RuntimeError):
            gu.main("p620", True)
        self.assertEqual(self.host.started, [])
        self.assertTrue(self.exists("runners-closed"))


class SwitchAndCanary(DrainCase):
    def held(self):
        with gu.DEPLOY_LOCK.open("a") as handle:
            try:
                fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                return True
        return False

    def test_the_host_is_verified_closed_and_p620_does_not_publish(self):
        verified = []
        profile = self.host.state / "profile"
        current = {"closure": OLD}

        def run(*args, **kwargs):
            if args[:2] == ("nix-env", "-p"):
                profile.unlink(missing_ok=True)
                profile.symlink_to(args[-1])
            return ""

        def switch(*args, **kwargs):
            current["closure"] = NEW
            return subprocess.CompletedProcess(args, 0, "", "")

        profile.symlink_to(OLD)
        self.patch(
            run=run,
            PROFILE=profile,
            current_closure=lambda: current["closure"],
            active_generation=lambda: 1,
            failed_units=set,
            graphical_sessions=set,
            verify_local=lambda host, failed, runners=True: verified.append(runners),
        )
        self.patch_object(gu.subprocess, "run", switch)
        gu.activate("p620", SHA, NEW)
        self.assertFalse(self.exists("verified"))
        profile.unlink()
        profile.symlink_to(OLD)
        current["closure"] = OLD
        gu.activate("razer", SHA, NEW)
        self.assertTrue(self.exists("verified"))
        self.assertEqual(verified, [False, False])

    def test_closed_verification_skips_only_the_runners(self):
        def run(*args, **kwargs):
            if args[-1] == "ActiveState":
                return "Result=success\nExecMainStatus=0\nActiveState=inactive"
            return "inactive"

        def runner_gate():
            raise RuntimeError("runners offline")

        self.patch(run=run, failed_units=set, runner_gate=runner_gate)
        gu.verify_local("p620", set(), runners=False)
        with self.assertRaises(RuntimeError):
            gu.verify_local("p620", set())

    def test_the_recheck_gate_leaves_the_runners_out(self):
        self.patch_object(gu, "gate", REAL_GATE)

        def runner_gate():
            raise RuntimeError("runners offline")

        self.patch(
            runner_gate=runner_gate,
            deploy_conflict=lambda *a: False,
            graphical_sessions=set,
            WINDOW="0-24",
        )
        self.assertTrue(gu.gate("p620", runners=False))
        with self.assertRaises(RuntimeError):
            gu.gate("p620")
        self.patch(WINDOW="0-0")
        with self.assertRaisesRegex(RuntimeError, "window"):
            gu.gate("p620", runners=False)

    def test_manual_p620_canary_is_checked_under_the_deploy_lock(self):
        seen = []
        self.host.current = NEW
        self.patch(
            failed_units=set,
            runner_gate=lambda: None,
            build_candidate=lambda sha, host: NEW,
            verify_local=lambda host, failed, runners=True: seen.append(
                (self.held(), runners)
            ),
        )
        self.assertEqual(gu.main("p620", False), 0)
        self.assertEqual(seen, [(True, True)])
        self.assertEqual(gu.read("verified"), {"sha": SHA, "candidate": NEW})

    def test_p620_drains_under_the_deploy_lock(self):
        seen = []
        self.patch(
            failed_units=set,
            runner_gate=lambda: None,
            build_candidate=lambda sha, host: NEW,
            bus_announce=lambda host, sha: lambda *a: seen.append("posted"),
            drained_activate=lambda sha, candidate: seen.append(self.held()) or True,
        )
        self.assertEqual(gu.main("p620", True), 0)
        self.assertEqual(seen, [True, "posted"])
        self.assertEqual(self.gates, [("p620", True), ("p620", True)])

    def test_razer_rereads_the_canary_just_before_switching(self):
        order = []
        canaries = iter([json.dumps({"sha": SHA}), json.dumps({"sha": "b" * 40})])

        def stage_ssh(command):
            if command.startswith("readlink"):
                return NEW
            order.append(("canary", self.held()))
            return next(canaries)

        self.patch(
            run=lambda *a, **k: NEW,
            stage_ssh=stage_ssh,
            bus_announce=lambda host, sha: order.append("announce"),
            activate=lambda *a: order.append("switched"),
        )
        key = mock.patch.dict(os.environ, {"STAGE_KEY_FILE": "/key"})
        with key, self.assertRaisesRegex(RuntimeError, "canary"):
            gu.main("razer", True)
        self.assertEqual(order, [("canary", False), "announce", ("canary", True)])


class Overrides(unittest.TestCase):
    def test_environment_overrides_and_defaults(self):
        def load(env):
            with mock.patch.dict(os.environ, env, clear=True):
                spec = importlib.util.spec_from_file_location("fresh", gu.__file__)
                module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(module)
            return module

        default = load({})
        self.assertEqual(default.REPO, "github:olafkfreund/nixos_config")
        self.assertEqual(default.RUNNER_REPO, "olafkfreund/nixarchy")
        self.assertEqual(default.ISSUE_REPO, "olafkfreund/nixos_config")
        self.assertEqual(default.runner_unit("-2"), "github-runner-nixarchy-2.service")
        self.assertEqual(len(default.EXPECTED_RUNNERS), 4)
        self.assertEqual(
            default.CI_WORKFLOWS,
            (("install-check.yml", "install"), ("omarchy-edge.yml", "verify")),
        )
        self.assertEqual(default.WINDOW, "4-5")
        self.assertEqual(default.BUS_ROOM, "#agents:freundcloud.org.uk")
        test = load(
            {
                "GUARDED_REPO": "github:o/disposable",
                "GUARDED_GIT_URL": "https://example/d.git",
                "GUARDED_RUNNER_REPO": "o/runners",
                "GUARDED_ISSUE_REPO": "o/issues",
                "GUARDED_RUNNER_UNIT": "drain",
                "GUARDED_RUNNER_NAME": "vm-drain",
                "GUARDED_CI_WORKFLOWS": "",
                "GUARDED_WINDOW": "0-24",
                "GUARDED_BUS_ROOM": "#test:example",
            }
        )
        self.assertEqual(test.REPO, "github:o/disposable")
        self.assertEqual(test.GIT_URL, "https://example/d.git")
        self.assertEqual(test.RUNNER_REPO, "o/runners")
        self.assertEqual(test.ISSUE_REPO, "o/issues")
        self.assertEqual(test.runner_unit(""), "github-runner-drain.service")
        self.assertIn("vm-drain-4", test.EXPECTED_RUNNERS)
        self.assertEqual(test.CI_WORKFLOWS, ())
        self.assertEqual(test.WINDOW, "0-24")
        self.assertEqual(test.BUS_ROOM, "#test:example")


class DeployHold(unittest.TestCase):
    def deploy(self, journal_check):
        with tempfile.TemporaryDirectory() as tmp:
            fakes = {
                "hostname": "echo testhost",
                "systemctl": "exit 0",
                # `test ! -e <journal>` answers as told; systemd-run and stop succeed.
                "sudo": f'[ "$1" = test ] && exit {journal_check}; exit 0',
            }
            for name, body in fakes.items():
                path = Path(tmp) / name
                path.write_text(f"#!/bin/sh\n{body}\n")
                path.chmod(0o755)
            ran = Path(tmp) / "ran"
            result = subprocess.run(
                [
                    "bash",
                    str(Path(__file__).with_name("deploy-hold.sh")),
                    "testhost",
                    "--",
                    "touch",
                    str(ran),
                ],
                env={**os.environ, "PATH": f"{tmp}:{os.environ['PATH']}"},
                text=True,
                capture_output=True,
                timeout=60,
                check=False,
            )
            return result, ran.exists()

    def test_refuses_during_a_drain_and_names_the_journal(self):
        result, ran = self.deploy(1)
        self.assertEqual((result.returncode, ran), (1, False), result.stderr)
        self.assertIn("/var/lib/guarded-upgrade/drain", result.stderr)
        result, ran = self.deploy(0)
        self.assertEqual((result.returncode, ran), (0, True), result.stderr)


if __name__ == "__main__":
    unittest.main()
