import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile, execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Turns, alternates, createTracker, workState, turnFor } from "../mods/reviewer/turns.js";

const run = (cmd, args, cwd) => execFileSync(cmd, args, { cwd, encoding: "utf8", env: { ...process.env, GIT_CONFIG_GLOBAL: "/dev/null", GIT_CONFIG_NOSYSTEM: "1" } });
const exec = (cmd, args, { cwd }) => new Promise(resolve => execFile(cmd, args, { cwd, env: { ...process.env, GIT_CONFIG_GLOBAL: "/dev/null", GIT_CONFIG_NOSYSTEM: "1" } }, (err, stdout, stderr) => resolve({ code: err?.code ?? 0, stdout, stderr })));

test("idle to working starts once; held keeps the turn open", () => {
  const edge = createTracker();
  assert.deepEqual(["resting", "working", "held", "working", "resting"].map(s => edge(workState(s === "held" ? ["blocked"] : s === "resting" ? ["idle"] : ["working"]))), [
    { started: false, ended: false }, { started: true, ended: false }, { started: false, ended: false },
    { started: false, ended: false }, { started: false, ended: true },
  ]);
});

test("snapshot is private, frozen at turn end, and selected by tab and repo", async () => {
  const root = mkdtempSync(join(tmpdir(), "reviewer-test-"));
  let turns;
  try {
    run("git", ["init", "-q", "-b", "main"], root);
    writeFileSync(join(root, "a.txt"), "first\n");
    run("git", ["add", "a.txt"], root);
    run("git", ["-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "init"], root);
    const index = join(root, ".git", "index"), before = [readFileSync(index), statSync(index).mtimeMs];
    turns = new Turns(exec);
    await turns.start(root, Date.now());
    writeFileSync(join(root, "a.txt"), "first\nturn\n");
    await turns.end();
    const last = turns.last(root);
    assert.equal(last.problem, undefined);
    assert.notEqual(last.from, last.to);
    assert.deepEqual([readFileSync(index), statSync(index).mtimeMs], before);
    const records = { tab1: { root, on: null, last } };
    assert.deepEqual(turnFor(records, "tab1", root, null), last);
    assert.equal(turnFor(records, "tab2", root, null), null);
    writeFileSync(join(root, "a.txt"), "later\n");
    await turns.refresh();
    assert.deepEqual(turns.last(root), last);
    const diff = await exec("env", [alternates(last.objects), "git", "diff", "--numstat", last.from, last.to], { cwd: root });
    const content = await exec("env", [alternates(last.objects), "git", "show", `${last.to}:a.txt`], { cwd: root });
    assert.equal(diff.code, 0);
    assert.match(diff.stdout, /^1\t0\ta.txt/m);
    assert.deepEqual([content.code, content.stdout], [0, "first\nturn\n"]);
  } finally {
    if (turns?.scratch) rmSync(turns.scratch, { recursive: true, force: true });
    rmSync(root, { recursive: true, force: true });
  }
});
