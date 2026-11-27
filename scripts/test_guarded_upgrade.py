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
            if props["ActiveState"] != "active":
                continue
            if self.behaviour[unit] == "silent":
                continue
            if not request.exists():
                ack = self.drain(unit) / "ack"
                if ack.exists() and '"draining"' in ack.read_text():
                    cancelled = {**json.loads(ack.read_text()), "state": "cancelled"}
                    ack.write_text(json.dumps(cancelled))
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

    def test_only_a_runner_that_never_saw_the_request_resolves_at_the_timeout(self):
        # No ack, or one for another request: resolved, but only after the timeout.
        for ack in (None, {"id": "old", "state": "draining"}):
            with self.subTest(ack=ack):
                self.setUp()
                journal = self.draining(UNITS[0])
                self.cancelled(UNITS[1:])
                path = self.host.drain(UNITS[0]) / "ack"
                path.unlink() if ack is None else path.write_text(json.dumps(ack))
                gu.defer(journal, "why")
                self.assertGreaterEqual(self.host.now - 1000, gu.SETTLE_TIMEOUT)
                self.assert_deferred([])
        self.setUp()
        journal = self.draining(UNITS[0])
        self.cancelled(UNITS[1:])
        with self.assertRaises(gu.ReopenFailed):
            gu.defer(journal, "why")
        self.assertEqual(gu.read("drain")["unresolved"], [UNITS[0]])

    def draining(self, unit):
        """A listener that saw request "r" and has not yet said how it ends."""
        self.host.ack(unit, id="r", invocation=unit, state="draining")
        self.host.behaviour[unit] = "silent"
        return {"request": "r", "invocations": dict(zip(gu.SUFFIXES, UNITS))}

    def cancelled(self, units):
        for unit in units:
            self.host.ack(unit, id="r", invocation=unit, state="cancelled")

    def test_defer_starts_a_listener_that_exits_after_a_late_decision(self):
        # Past its last check, not yet exited: active, still acking "draining".
        journal = self.draining(UNITS[0])
        self.cancelled(UNITS[1:])
        exit_at = self.host.now + gu.SETTLE_TIMEOUT / 2

        def leave():
            if self.host.now >= exit_at and not self.host.started:
                self.host.units[UNITS[0]]["ActiveState"] = "inactive"

        self.host.on_sleep = leave
        gu.defer(journal, "why")
        self.assert_deferred([(UNITS[0],)])

    def test_a_runner_exiting_past_the_settle_timeout_is_recovered_later(self):
        journal = self.draining(UNITS[0])
        self.cancelled(UNITS[1:])
        with self.assertRaises(gu.ReopenFailed):
            gu.defer(journal, "why")
        self.assertEqual(gu.read("drain")["phase"], "cancelling")
        self.assertEqual(self.host.started, [])
        self.host.units[UNITS[0]]["ActiveState"] = "inactive"
        self.assertEqual(gu.recover("p620"), 0)
        self.assert_deferred([(UNITS[0],)])

    def test_resumed_is_judged_on_the_current_invocations_own_ack(self):
        journal = {"request": "r", "invocations": {"": "one"}}
        for invocation in ("one", "two"):  # the original one, and a later one
            up = {"ActiveState": "active", "InvocationID": invocation}
            for ack_id, state, want in (
                ("r", "cancelled", True),
                ("old", "draining", True),
                ("r", "draining", False),
                ("r", "exited-idle", False),
                ("r", "exited-after-job", False),
            ):
                self.host.ack(UNITS[0], id=ack_id, invocation=invocation, state=state)
                self.assertEqual(
                    gu.resumed("", journal, up), want, (invocation, ack_id, state)
                )
            down = {**up, "ActiveState": "inactive"}
            self.assertFalse(gu.resumed("", journal, down))
        # What an earlier invocation said is not the new one's word.
        self.host.ack(UNITS[0], id="r", invocation="one", state="exited-idle")
        up = {"ActiveState": "active", "InvocationID": "two"}
        self.assertTrue(gu.resumed("", journal, up))

    def test_a_restarted_listener_that_exits_on_the_old_request_is_started(self):
        # It restarted after start_drain and is about to leave when defer begins.
        journal = self.draining(UNITS[0])
        self.cancelled(UNITS[1:])
        self.host.units[UNITS[0]]["InvocationID"] = "restarted"
        self.host.ack(UNITS[0], id="r", invocation="restarted", state="draining")

        def leave():
            if not self.host.started:
                self.host.ack(
                    UNITS[0], id="r", invocation="restarted", state="exited-idle"
                )
                self.host.units[UNITS[0]]["ActiveState"] = "inactive"

        self.host.on_sleep = leave
        gu.defer(journal, "why")
        self.assert_deferred([(UNITS[0],)])

    def test_a_cancelled_listener_that_dies_in_the_settle_window_is_started(self):
        self.cancelled(UNITS)

        def die():
            if not self.host.started:
                self.host.units[UNITS[0]]["ActiveState"] = "failed"

        self.host.on_sleep = die
        gu.defer({"request": "r", "invocations": dict(zip(gu.SUFFIXES, UNITS))}, "why")
        self.assert_deferred([(UNITS[0],)])

    def test_a_unit_started_in_the_last_settle_round_is_read_again(self):
        self.cancelled(UNITS)
        end = self.host.now + gu.SETTLE_TIMEOUT

        def die_last():
            if self.host.now >= end:
                self.host.units[UNITS[0]]["ActiveState"] = "inactive"

        self.host.on_sleep = die_last
        gu.defer({"request": "r", "invocations": dict(zip(gu.SUFFIXES, UNITS))}, "why")
        self.assert_deferred([(UNITS[0],)])

    def test_a_runner_restarting_during_the_drain_defers_early(self):
        seen = self.fake_activate()
        self.host.behaviour[UNITS[0]] = "silent"

        def restart():
            self.host.units[UNITS[0]]["InvocationID"] = "restarted"

        self.host.on_sleep = restart
        self.assertFalse(gu.drained_activate(SHA, NEW))
        self.assertEqual(seen, {})
        self.assertLess(self.host.now - 1000, gu.DRAIN_TIMEOUT / 2)
        self.assertTrue(
            any(f"restarted during the drain: {UNITS[0]}" in m for m in self.logs)
        )

    def break_drain_path(self, unit, kind):
        if kind == "file":
            self.host.drain(unit).write_text("")
        else:
            elsewhere = self.host.state / "elsewhere"
            elsewhere.mkdir(exist_ok=True)
            self.host.drain(unit).symlink_to(elsewhere)

    def test_one_unusable_drain_path_defers_and_leaves_nothing_behind(self):
        # It never took a request, so an active runner there needs no recovery.
        for kind in ("file", "symlink"):
            with self.subTest(kind):
                self.setUp()
                seen = self.fake_activate()
                self.break_drain_path(UNITS[0], kind)
                self.assertFalse(gu.drained_activate(SHA, NEW))
                self.assertEqual(seen, {})
                self.assertFalse(self.exists("drain"))
                self.assertFalse(self.exists("runners-closed"))
                self.assertTrue(
                    any(f"{UNITS[0]}: cannot write" in m for m in self.logs)
                )

    def test_each_written_request_is_recorded_in_the_journal(self):
        self.break_drain_path(UNITS[2], "file")
        journal = gu.start_drain(SHA, NEW)
        with self.assertRaises(RuntimeError):
            gu.close_and_wait(journal)
        self.assertEqual(gu.read("drain")["requested"], ["", "-2"])

    def test_a_path_broken_after_its_request_was_written_stays_unresolved(self):
        self.cancelled(UNITS[1:])
        self.break_drain_path(UNITS[0], "file")
        journal = {"request": "r", "requested": [""], "invocations": {}}
        with self.assertRaises(gu.ReopenFailed):
            gu.defer(journal, "why")
        self.assertEqual(gu.read("drain")["unresolved"], [UNITS[0]])

    def test_an_unusable_path_with_a_runner_down_stays_unresolved(self):
        self.break_drain_path(UNITS[0], "file")
        self.cancelled(UNITS[1:])
        self.host.units[UNITS[0]]["ActiveState"] = "activating"
        with self.assertRaises(gu.ReopenFailed):
            gu.defer({"request": "r", "invocations": {}}, "why")

    def test_reopen_with_one_unremovable_request_still_opens_the_others(self):
        for requested in ([""], []):
            with self.subTest(requested=requested):
                self.setUp()
                for unit in UNITS:
                    self.host.units[unit]["ActiveState"] = "inactive"
                (self.host.state / "runners-closed").touch()
                for suffix in gu.SUFFIXES[1:]:
                    gu.write_request(suffix, "r")
                self.break_drain_path(UNITS[0], "file")
                journal = {"phase": "orphan", "requested": requested}
                if requested:
                    with self.assertRaises(gu.ReopenFailed):
                        gu.reopen_and_clear(journal)
                    self.assertEqual(gu.read("drain")["unresolved"], [UNITS[0]])
                else:
                    gu.reopen_and_clear(journal)
                    self.assertFalse(self.exists("drain"))
                self.assertFalse(self.exists("runners-closed"))
                self.assertEqual(self.requests(), [])
                self.assertEqual(self.host.started, [tuple(UNITS)])

    def test_a_job_past_the_deadline_defers(self):
        seen = self.fake_activate()
        self.host.behaviour[UNITS[3]] = "busy"
        self.assertFalse(gu.drained_activate(SHA, NEW))
        self.assertEqual(seen, {})
        self.assertGreaterEqual(self.host.now - 1000, gu.DRAIN_TIMEOUT)
        self.assertLess(
            self.host.now - 1000, gu.DRAIN_TIMEOUT + gu.SETTLE_TIMEOUT + 2 * gu.POLL
        )
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
        self.cancelled(UNITS)
        self.host.units[unit]["ActiveState"] = "deactivating"

        def finish():
            if not self.host.started:
                self.host.units[unit]["ActiveState"] = "inactive"

        self.host.on_sleep = finish
        gu.defer({"request": "r", "invocations": dict(zip(gu.SUFFIXES, UNITS))}, "why")
        self.assertEqual(self.host.started, [(unit,)])

    def test_defer_with_every_unit_cancelled_starts_nothing(self):
        self.cancelled(UNITS)
        gu.defer({"request": "r", "invocations": dict(zip(gu.SUFFIXES, UNITS))}, "why")
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

    def test_a_runner_exiting_during_the_github_call_is_not_ready(self):
        def github(path):
            reply = self.host.github(path)
            self.host.units[UNITS[0]]["ActiveState"] = "inactive"
            return reply

        self.patch(github=github)
        with self.assertRaises(RuntimeError):
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
                    **({"settled": phase} if phase.startswith("settled-") else {}),
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

    def test_draining_and_cancelling_defer(self):
        for phase in ("draining", "cancelling"):
            self.host.started.clear()
            self.interrupted(phase)
            self.assertEqual(gu.main("p620", True), 0, phase)
            self.assert_deferred([tuple(UNITS)])

    def test_switching_with_a_transaction_rolls_back_then_reopens(self):
        self.interrupted("switching")
        gu.save("transaction", {"sha": SHA})
        self.assertEqual(gu.main("p620", True), 1)
        self.assertEqual(self.rolled_back, [SHA])
        self.assert_reopened()
        self.assertFalse(self.exists("verified"))

    def killed_activation(self, when):
        """The real activate() on a journal in "switching", killed at `when`."""

        class Killed(BaseException):
            pass

        profile = self.host.state / "profile"
        profile.symlink_to(OLD)
        real_run, real_unlink = self.host.run, gu.Path.unlink

        def run(*args, **kwargs):
            if args[0] == "nix-env":
                real_unlink(profile)
                profile.symlink_to(args[-1])
            if args[0] in ("nix-env", "nix-store"):
                return ""
            return real_run(*args, **kwargs)

        def switch(*args, **kwargs):
            self.host.current = NEW
            return subprocess.CompletedProcess(args, 0, "", "")

        def unlink(path, *args, **kwargs):
            if path.name != "transaction":
                return real_unlink(path, *args, **kwargs)
            if when == "after-unlink":
                real_unlink(path, *args, **kwargs)
            raise Killed

        def verify(host, failed, runners=True):
            if when == "verifying":
                raise Killed

        self.interrupted("switching")
        with (
            mock.patch.multiple(
                gu,
                run=run,
                PROFILE=profile,
                current_closure=lambda: self.host.current,
                active_generation=lambda: 1,
                failed_units=set,
                graphical_sessions=set,
                verify_local=verify,
            ),
            mock.patch.object(gu.subprocess, "run", switch),
            mock.patch.object(gu.Path, "unlink", unlink),
            self.assertRaises(Killed),
        ):
            gu.activate("p620", SHA, NEW)

    def test_a_kill_before_the_transaction_is_deleted_keeps_the_commit(self):
        self.killed_activation("before-unlink")
        self.assertTrue(self.exists("transaction"))
        self.assertEqual(gu.main("p620", True), 0)
        self.assert_committed()

    def test_a_kill_after_the_transaction_is_deleted_keeps_the_commit(self):
        self.killed_activation("after-unlink")
        self.assertFalse(self.exists("transaction"))
        self.assertEqual(gu.main("p620", True), 0)
        self.assert_committed()

    def test_a_kill_during_verification_rolls_back_and_publishes_nothing(self):
        self.killed_activation("verifying")
        self.assertEqual(gu.main("p620", True), 1)
        self.assertEqual(self.rolled_back, [SHA])
        self.assert_reopened()
        self.assertFalse(self.exists("verified"))

    def test_a_failed_rollback_root_cleanup_keeps_the_commit(self):
        profile = self.host.state / "profile"
        profile.symlink_to(OLD)
        real_run, real_unlink = self.host.run, gu.Path.unlink

        def run(*args, **kwargs):
            if args[0] == "nix-env":
                real_unlink(profile)
                profile.symlink_to(args[-1])
            if args[0] in ("nix-env", "nix-store"):
                return ""
            return real_run(*args, **kwargs)

        def switch(*args, **kwargs):
            self.host.current = NEW
            return subprocess.CompletedProcess(args, 0, "", "")

        def unlink(path, *args, **kwargs):
            if path.name == "rollback-root":
                raise OSError("read-only")
            return real_unlink(path, *args, **kwargs)

        self.patch(
            run=run,
            PROFILE=profile,
            current_closure=lambda: self.host.current,
            active_generation=lambda: 1,
            failed_units=set,
            graphical_sessions=set,
            verify_local=lambda *a, **k: None,
            gate=lambda *a, **k: None,
        )
        self.patch_object(gu.subprocess, "run", switch)
        self.patch_object(gu.Path, "unlink", unlink)
        self.assertTrue(gu.drained_activate(SHA, NEW))
        self.assert_committed()

    def assert_committed(self):
        self.assertEqual(self.rolled_back, [])
        self.assert_reopened()
        self.assertFalse(self.exists("transaction"))
        self.assertEqual(gu.read("verified"), {"sha": SHA, "candidate": NEW})

    def test_settled_commit_with_a_transaction_commits_without_rolling_back(self):
        # "reopen-failed" keeps the verdict in "settled".
        for phase in ("settled-commit", "reopen-failed"):
            self.host.started.clear()
            self.host.current = NEW
            self.interrupted("settled-commit")
            gu.save("drain", {**gu.read("drain"), "phase": phase})
            gu.save("transaction", {"sha": SHA})
            (self.host.state / "rollback-root").touch()
            self.assertEqual(gu.main("p620", True), 0, phase)
            self.assert_committed()
            self.assertFalse(self.exists("rollback-root"))
            (self.host.state / "verified").unlink()

    def test_settled_commit_with_a_transaction_not_current_is_not_published(self):
        self.interrupted("settled-commit")
        gu.save("transaction", {"sha": SHA})
        self.assertEqual(gu.main("p620", True), 0)
        self.assertEqual(self.rolled_back, [])
        self.assertFalse(self.exists("verified"))

    def test_switching_without_a_transaction_reopens_without_publishing(self):
        # No verdict: killed before the transaction was saved, or after a rollback.
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

    def test_a_retried_reopen_still_publishes_a_committed_switch(self):
        self.interrupted("settled-commit")
        self.host.current = NEW
        self.host.offline = {UNITS[0]}
        with self.assertRaises(gu.ReopenFailed):
            gu.main("p620", True)
        self.assertEqual(gu.read("drain")["phase"], "reopen-failed")
        self.assertFalse(self.exists("verified"))
        self.host.offline = set()
        for unit in UNITS:
            self.host.units[unit]["ActiveState"] = "inactive"
        self.assertEqual(gu.main("p620", True), 0)
        self.assertEqual(gu.read("verified"), {"sha": SHA, "candidate": NEW})
        self.assertFalse(self.exists("drain"))

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

    def test_an_unparseable_journal_is_reopened_like_an_orphan(self):
        for junk in ("", '{"phase": "drai', "[1]", "{}"):
            with self.subTest(junk=junk):
                self.host.started.clear()
                self.logs.clear()
                self.interrupted(None, closed=False)
                (self.host.state / "drain").write_text(junk)
                self.assertEqual(gu.main("p620", True), 0)
                self.assertTrue(any("unreadable" in m for m in self.logs))
                self.assert_reopened()
                self.assertFalse(self.exists("verified"))

    def test_the_journal_is_durable_before_and_after_the_rename(self):
        order = []
        fsync, replace = os.fsync, os.replace

        def traced_fsync(fd):
            order.append(os.readlink(f"/proc/self/fd/{fd}"))
            fsync(fd)

        def traced_replace(*args):
            order.append("rename")
            replace(*args)

        self.patch_object(gu.os, "fsync", traced_fsync)
        self.patch_object(gu.os, "replace", traced_replace)
        gu.save("drain", {"phase": "draining"})
        state = os.path.realpath(self.host.state)
        self.assertEqual(order, [f"{state}/drain.tmp", "rename", state])

    def test_recover_mode_recovers_and_then_stops(self):
        def resolve_main():
            raise AssertionError("recover mode went on to an upgrade")

        self.patch(resolve_main=resolve_main)
        (self.host.state / "pause").unlink()
        self.assertEqual(gu.cli("p620", "recover"), 0)
        self.assertEqual(self.host.calls, [])
        self.interrupted("draining")
        self.assertEqual(gu.cli("p620", "recover"), 0)
        self.assert_deferred([tuple(UNITS)])

    def test_recover_mode_leaves_a_running_upgrade_alone(self):
        self.interrupted("draining")
        with (self.host.state / "lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertEqual(gu.cli("p620", "recover"), 0)
        self.assertEqual(self.host.started, [])
        self.assertTrue(self.exists("runners-closed"))

    def test_recover_mode_never_switches_with_a_leftover_transaction(self):
        def switch(*args, **kwargs):
            raise AssertionError(f"recover mode switched: {args}")

        self.patch_object(gu.subprocess, "run", switch)
        for phase in ("switching", "draining", "settled-rollback", None):
            with self.subTest(phase=phase):
                self.logs.clear()
                self.interrupted(phase)
                gu.save("transaction", {"sha": SHA})
                journal = gu.read("drain")
                self.assertEqual(gu.cli("p620", "recover"), 1)
                self.assertEqual(self.rolled_back, [])
                self.assertEqual(self.host.calls, [])
                self.assertEqual(self.requests(), UNITS)
                self.assertTrue(self.exists("runners-closed"))
                self.assertTrue(self.exists("transaction"))
                self.assertEqual(gu.read("drain"), journal)
                self.assertTrue(any("timer run" in m for m in self.logs))
                (self.host.state / "drain").unlink(missing_ok=True)
        # The timer run still rolls back.
        self.interrupted("switching")
        self.assertEqual(gu.main("p620", True), 1)
        self.assertEqual(self.rolled_back, [SHA])
        self.assert_reopened()

    def test_recover_mode_finishes_a_committed_cleanup_without_switching(self):
        def switch(*args, **kwargs):
            raise AssertionError(f"recover mode switched: {args}")

        self.patch_object(gu.subprocess, "run", switch)
        for phase in ("settled-commit", "reopen-failed"):
            with self.subTest(phase=phase):
                self.host.started.clear()
                self.host.current = NEW
                self.interrupted("settled-commit")
                gu.save("drain", {**gu.read("drain"), "phase": phase})
                gu.save("transaction", {"sha": SHA})
                self.assertEqual(gu.cli("p620", "recover"), 0)
                self.assert_committed()
                (self.host.state / "verified").unlink()

    def test_an_invalid_journal_is_reopened_like_an_orphan(self):
        good = {
            "phase": "switching",
            "sha": SHA,
            "candidate": NEW,
            "request": "r",
            "invocations": {"": "x"},
            "requested": [""],
        }
        commit = {**good, "phase": "settled-commit", "settled": "settled-commit"}
        self.assertTrue(gu.valid_journal(good))
        self.assertTrue(gu.valid_journal(commit))
        self.assertTrue(gu.valid_journal({"phase": "reopen-failed", "unresolved": []}))
        bad = [None, {**good, "phase": "bogus"}, {**good, "phase": []}]
        for key in ("sha", "candidate", "request", "invocations", "requested"):
            bad.append({**good, key: None})
        bad += [
            {**good, "invocations": {"": 1}},
            {**good, "requested": [1]},
            {**good, "settled": "settled-commit"},
            {**commit, "settled": "yes"},
            {k: v for k, v in commit.items() if k != "sha"},
            {k: v for k, v in commit.items() if k != "candidate"},
        ]
        for journal in bad:
            with self.subTest(journal=journal):
                self.host.started.clear()
                self.logs.clear()
                self.interrupted(None, closed=False)
                gu.save("drain", journal)
                self.assertEqual(gu.main("p620", True), 0)
                self.assertTrue(any("unreadable" in m for m in self.logs))
                self.assert_reopened()
                self.assertFalse(self.exists("verified"))

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
    def deploy(self, present):
        with tempfile.TemporaryDirectory() as tmp:
            fakes = {
                "hostname": "echo testhost",
                "systemctl": "exit 0",
                # `test ! -e <path>` fails for the one present; the rest succeed.
                "sudo": f'[ "$1 $4" = "test {present}" ] && exit 1; exit 0',
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

    def test_refuses_during_a_drain_and_names_what_is_left(self):
        for name in ("drain", "runners-closed"):
            path = f"/var/lib/guarded-upgrade/{name}"
            result, ran = self.deploy(path)
            self.assertEqual((result.returncode, ran), (1, False), result.stderr)
            self.assertIn(path, result.stderr)
            for hint in (
                "transaction",
                "file or symlink",
                "rm -f /var/lib/guarded-upgrade/drain",
                "systemctl start github-runner-nixarchy",
            ):
                self.assertIn(hint, result.stderr)
        result, ran = self.deploy("none")
        self.assertEqual((result.returncode, ran), (0, True), result.stderr)


if __name__ == "__main__":
    unittest.main()
