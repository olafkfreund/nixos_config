import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile, execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { runInNewContext } from "node:vm";
import { Turns, READ, alternates, turnFor, createTracker, workState } from "../mods/reviewer/turns.js";
import { commentState } from "../mods/reviewer/stale.js";
import { confirmed } from "../mods/reviewer/paste.js";

const source = readFileSync(new URL("../mods/reviewer/main.js", import.meta.url), "utf8")
  .replace(/^import .*;\n/gm, "").replace("export default class Changes", "class Changes") + "\nglobalThis.Changes = Changes;";
const gitEnv = { ...process.env, GIT_CONFIG_GLOBAL: "/dev/null", GIT_CONFIG_NOSYSTEM: "1" };
const run = (cmd, args, cwd) => execFileSync(cmd, args, { cwd, env: gitEnv, encoding: "utf8" });
const exec = (cmd, args, { cwd }) => new Promise((resolve) => execFile(cmd, args, { cwd, env: gitEnv },
  (error, stdout, stderr) => resolve({ code: error?.code ?? 0, stdout, stderr })));

function panel(root, store, session) {
  const context = {
    View: class {}, Turns, READ, alternates, turnFor, createTracker, workState, commentState,
    tokenize: (text) => ({ spans: [{ text, cls: "" }], state: null }), languageOf: () => null,
    spaces: () => [{ active: true, folder: root }], panes: () => [], focused: () => ({ tab: "tab" }),
    exec, readTextFile: async (path) => readFileSync(path, "utf8"), watchFolder: () => {},
    props: () => ({}), settings: () => ({}), shared: (key) => store[key], setShared: (key, value) => { store[key] = value; },
    VirtualListScrollHandle: { new: () => ({ scroll_to_item() {} }) },
  };
  runInNewContext(source.replace(/const SESSION = [^;]+;/, `const SESSION = "${session}";`), context);
  const view = Object.create(context.Changes.prototype);
  Object.assign(view, { files: [], rows: [], comments: [], scope: "work", sha: null, range: ["HEAD"], root: null,
    on: null, scopeInfo: null, context: null, open: null, closed: true, loading: false, busy: false,
    setLines(lines) { this.lines = lines; }, watch() {}, rebuild() {},
  });
  const tasks = [];
  const cx = { spawn: (fn) => { tasks.push(Promise.resolve().then(() => fn(cx))); }, notify() {} };
  return { view, context, async refresh() { view.refresh(cx); await Promise.all(tasks.splice(0)); } };
}

test("adapted reader lists snapshot stats, diff and end tree content after later edits", async () => {
  const root = mkdtempSync(join(tmpdir(), "reviewer-reader-"));
  let turns;
  try {
    run("git", ["init", "-q", "-b", "main"], root);
    writeFileSync(join(root, "a.txt"), "one\ntwo\nthree\n");
    writeFileSync(join(root, "b.txt"), "old\n");
    run("git", ["add", "-A"], root);
    run("git", ["-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "init"], root);
    turns = new Turns(exec);
    await turns.start(root, Date.now());
    writeFileSync(join(root, "a.txt"), "one\nagent\nthree\n");
    writeFileSync(join(root, "b.txt"), "new\n");
    await turns.refresh();
    await turns.end();
    const last = turns.last(root), store = { "reviewer.scope": { [`:${root}`]: "turn" },
      "reviewer.turns": { tab: { root, on: null, last } } };
    writeFileSync(join(root, "a.txt"), "one\nmanual\nthree\n");
    const { view, refresh } = panel(root, store, "B");
    await refresh();
    assert.equal(view.error, null);
    assert.deepEqual(Array.from(view.files, (f) => [f.path, f.status, f.add, f.del]),
      [["a.txt", "M", 1, 1], ["b.txt", "M", 1, 1]]);
    const lines = await view.readRows("a.txt");
    assert.ok(lines.includes("+agent"));
    assert.ok(lines.includes("-two"));
    assert.ok(!lines.some((line) => line.includes("manual")));
    writeFileSync(join(root, "a.txt"), "different again\n");
    assert.deepEqual(await view.readRows("a.txt"), lines);
  } finally {
    if (turns?.scratch) rmSync(turns.scratch, { recursive: true, force: true });
    rmSync(root, { recursive: true, force: true });
  }
});

test("paste keeps unsent drafts after a scope switch and clears selected earlier turns", async () => {
  const root = "/repo", store = { "reviewer.drafts": {} };
  const a = panel(root, store, "A").view;
  Object.assign(a, { root, scope: "turn", scopeInfo: { turn: { gen: 1 } } });
  const oldKey = a.draftKey();
  store["reviewer.drafts"][oldKey] = [{ id: "old", path: "a.txt", quote: "saved" }];
  const b = panel(root, store, "B").view;
  Object.assign(b, { root, scope: "turn", scopeInfo: { turn: { gen: 1 } } });
  const newKey = b.draftKey();
  assert.notEqual(newKey, oldKey);
  assert.deepEqual(Array.from(b.loadDrafts("turn")), []);
  store["reviewer.drafts"][newKey] = [{ id: "new", path: "b.txt" }];
  const dialogSource = readFileSync(new URL("../mods/reviewer/dialog.js", import.meta.url), "utf8")
    .replace(/^import .*;\n/gm, "").replace("export class Dialog", "class Dialog") + "\nglobalThis.Dialog = Dialog;";
  const agent = { address: "fake-pane", tab: "tab", status: "done" };
  let screen = "", clipboard = "previous", closed = false, toast = null;
  let pasted;
  const pasteStarted = new Promise((resolve) => { pasted = resolve; });
  const runtime = { confirmed, setTimeout, agents: () => [agent], focused: () => ({ tab: "tab", terminal: agent.address }),
    shared: (key) => store[key], setShared: (key, value) => { store[key] = value; },
    props: () => ({ overlay: "fake" }), closeOverlay: () => { closed = true; },
    hc: async () => ({ code: 0, stdout: screen }), run: (command) => { if (command === "terminal.paste") { screen += clipboard; pasted(); } },
    notify: (message) => { toast = message; },
  };
  runInNewContext(dialogSource, runtime);
  const dialog = Object.create(runtime.Dialog.prototype);
  Object.assign(dialog, { note: "", context: "Review current turn", drafts: [{ key: newKey, ids: ["new"] }],
    earlier: [{ key: oldKey, ids: ["old"], context: "Earlier turn" }], includeEarlier: true,
    repo: root, scope: "turn", sending: false, pick: null });
  const tasks = [];
  const cx = { spawn: (fn) => tasks.push(Promise.resolve().then(() => fn(cx))), notify() {},
    read_from_clipboard: () => clipboard, write_to_clipboard: (text) => { clipboard = text; } };
  dialog.send(cx);
  await Promise.race([pasteStarted, new Promise((_, reject) => setTimeout(() => reject(new Error(dialog.error || "paste did not start")), 1000))]);
  store["reviewer.drafts"][newKey].push({ id: "unsent", path: "c.txt" });
  store["reviewer.drafts"][`:${root}:work`] = [{ id: "work", path: "d.txt" }];
  b.refresh = () => {};
  b.setScope("work", { notify() {} });
  await Promise.all(tasks);
  assert.equal(closed, true, dialog.error);
  assert.match(toast?.title ?? "", /Pasted into/);
  assert.deepEqual(store["reviewer.drafts"][newKey].map((comment) => comment.id), ["unsent"]);
  assert.equal(store["reviewer.drafts"][oldKey], undefined);
  assert.deepEqual(store["reviewer.drafts"][`:${root}:work`].map((comment) => comment.id), ["work"]);
  assert.equal(clipboard, "previous");
});

test("new Turns instances keep drafts separate across A to B to A", () => {
  const root = "/repo", store = {}, { view } = panel(root, store, "A");
  const a = { root, on: null, turnsId: "first", turns: { last: () => ({ gen: 1 }) } };
  view.publishTurn("tab", a);
  Object.assign(view, { root, scope: "turn", scopeInfo: { turn: store["reviewer.turns"].tab.last } });
  const first = view.draftKey();
  store["reviewer.drafts"] = { [first]: [{ id: "first", path: "a.txt" }] };
  const b = { root: "/other", on: null, turnsId: "second", turns: { last: () => ({ gen: 1 }) } };
  view.publishTurn("tab", b);
  a.turns = { last: () => ({ gen: 1 }) }; a.turnsId = "third";
  view.publishTurn("tab", a);
  view.scopeInfo.turn = store["reviewer.turns"].tab.last;
  assert.notEqual(view.draftKey(), first);
  assert.equal(store["reviewer.drafts"][first][0].id, "first");
  assert.equal(view.loadDrafts("turn").length, 0);
});

test("stale check rereads commented file after switching, including range interiors", async () => {
  const root = "/repo", store = {};
  const { view } = panel(root, store, "B");
  Object.assign(view, { root, context: "repo", scope: "work", files: [{ path: "a.txt" }, { path: "b.txt" }], open: "b.txt" });
  const rows = ["first", "middle", "last", "separate"].map((text, i) => ({ kind: "+", number: i + 1, text }));
  const quote = (list) => list.map((r) => `${String(r.number).padStart(5)} ${r.kind} ${r.text}`).join("\n");
  view.quote = quote;
  view.comments = [
    { id: "single", path: "a.txt", from: rows[3], to: rows[3], quote: quote(rows.slice(3)) },
    { id: "range", path: "a.txt", from: rows[0], to: rows[2], quote: quote(rows.slice(0, 3)) },
  ];
  const original = view.comments.map((comment) => comment.quote);
  view.readRows = async () => ["@@ -1,4 +1,4 @@", "+first", "+edited", "+last", "+changed"];
  await view.checkComments();
  assert.deepEqual(Array.from(view.commentStates.values()), ["lines changed", "lines changed"]);
  assert.deepEqual(view.comments.map((comment) => comment.quote), original);
});

test("hidden tracker remains the sole snapshot owner when panel opens and drops an old send", () => {
  const store = { "reviewer.send": { id: "old", text: "never paste" },
    "reviewer.drafts": { ":/repo:work": [{ id: "saved", path: "a.txt" }] } };
  const { view, context } = panel("/repo", store, "B");
  let pasteCalls = 0;
  context.run = () => { pasteCalls++; };
  context.hc = () => { pasteCalls++; };
  const periods = [];
  const cx = { timer: { every: (ms) => periods.push(ms) }, focus_handle: () => ({}), spawn() {} };
  context.props = () => ({ turns: true });
  view.init(null, cx);
  assert.deepEqual(periods, [250]);
  assert.equal(view.trackers.size, 0);
  context.props = () => ({});
  context.TextareaState = { new: () => ({ set_auto_grow() {}, on() {} }) };
  const visible = Object.create(context.Changes.prototype);
  visible.refresh = () => {};
  visible.init(null, cx);
  assert.deepEqual(periods, [250, 10000]);
  assert.equal(visible.trackers, undefined);
  assert.equal(store["reviewer.send"], null);
  assert.equal(store["reviewer.handled"], undefined);
  assert.equal(pasteCalls, 0);
  assert.equal(store["reviewer.drafts"][":/repo:work"][0].id, "saved");
});

test("tracker ends a turn after delayed repository discovery", async () => {
  const { view, context } = panel("/repo", {}, "B");
  const calls = [];
  let release;
  context.agents = () => [{ tab: "tab", pane: "pane", space: "space", status }];
  context.panes = () => [{ pane: "pane", cwd: "/repo" }];
  context.spaces = () => [{ id: "space", machine: null }];
  context.exec = async () => {
    await new Promise(resolve => { release = resolve; });
    return { code: 0, stdout: "/repo\n" };
  };
  context.Turns = class {
    async start() { calls.push("start"); }
    async end() { calls.push("end"); }
    last() { return { gen: 1 }; }
  };
  const tasks = [], timers = [];
  const cx = { timer: { every: (_ms, fn) => timers.push(fn) }, spawn: fn => {
    tasks.push(Promise.resolve().then(() => fn(cx)));
  }, notify() {} };
  view.initTracker(cx);
  let status = "idle";
  timers[0](cx);
  status = "working";
  timers[0](cx);
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(typeof release, "function");
  status = "idle";
  timers[0](cx);
  release();
  await Promise.all(tasks);
  assert.deepEqual(calls, ["start", "end"]);
});
