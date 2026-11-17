// Turns: one tab and one repository, with snapshots in a private temp folder.
export const READ = ["--no-optional-locks", "-c", "core.fsmonitor=false", "-c", "diff.autoRefreshIndex=false"];
export const alternates = (dir) => `GIT_ALTERNATE_OBJECT_DIRECTORIES="${dir.replace(/[\\"]/g, "\\$&")}"`;

// herdr reports `working` a little after the agent starts, and the pane samples it every 250 ms.
const RACE_BEFORE = 1250;
// A watch batch arrives up to about 150 ms after the write it reports.
const RACE_AFTER = 300;

/** @param {string[]} statuses @returns {"working" | "resting" | "held"} */
export function workState(statuses) {
  if (statuses.includes("working")) return "working";
  return statuses.every((s) => s === "idle" || s === "done") ? "resting" : "held";
}

export const turnFor = (turns, tab, root, on) => turns?.[tab]?.root === root && turns[tab].on === on ? turns[tab].last : null;

// A start is a move into work while no turn is open; an end, a return to rest. `held` (an agent
// blocked on a question) keeps a turn open, and with one agent blocked, another's turns still
// start. The first sample starts nothing: a turn already running has no baseline.
export function createTracker() {
  let seen = false, open = false;
  return (state) => {
    const edge = { started: state === "working" && seen && !open, ended: open && state === "resting" };
    seen = true;
    open = state === "working" || (state === "held" && open);
    return edge;
  };
}

// The snapshot's git writes no split index (a sharedindex file under .git) and runs no hook,
// since a hook such as post-index-change can write anywhere.
const SNAP = [...READ, "-c", "core.splitIndex=false", "-c", "core.hooksPath=/dev/null"];
const SPLIT = "git's split index is on in this repo, so it has no turn snapshot";

async function git(exec, root, env, args, config = []) {
  const r = await exec("env", [...env, "git", ...SNAP, ...config, ...args], { cwd: root });
  if (r.code !== 0) throw new Error(`git ${args[0]} failed in ${root}: ${r.stderr.trim()}`);
  return r.stdout;
}

/**
 * The working tree as a tree object, staged into a copy of the repo's index (`cp -p` keeps its
 * mtime, without which git misses a same-size edit) and stored in `store`. No alternates while
 * writing: git would bump the mtime of each repo object it finds already there.
 */
async function snapshot(exec, root, b, store) {
  // Reading a split index bumps its sharedindex file's mtime, and it can be turned on mid-turn.
  if ((await exec("find", [b.gitDir, "-maxdepth", "1", "-name", "sharedindex.*"], { cwd: root })).stdout.trim()) throw new Error(SPLIT);
  const cp = await exec("cp", ["-p", `${b.gitDir}/index`, b.index], { cwd: root });
  // A repo with no index yet stages from nothing.
  if (cp.code !== 0 && (await exec("test", ["-e", `${b.gitDir}/index`], { cwd: root })).code === 0) throw new Error(cp.stderr.trim());
  const env = [`GIT_INDEX_FILE=${b.index}`, `GIT_OBJECT_DIRECTORY=${store}`];
  // A nested repo with no commit fails its own path, and --ignore-errors stages the rest with
  // exit code 1; past that, git stopped and the copy still holds the index.
  const add = await exec("env", [...env, "git", ...SNAP, ...b.noFilters, "add", "-A", "--ignore-errors"], { cwd: root });
  if (add.code > 1) throw new Error(`snapshot staging failed in ${root}: ${add.stderr.trim()}`);
  // Clean files' blobs sit in the repo, not the store. write-tree rereads a file whose mtime
  // matches the index's, so it needs the filters off too.
  return (await git(exec, root, env, ["write-tree", "--missing-ok"], b.noFilters)).trim();
}

// Clean filters (git-lfs) write under .git, so the snapshot stores files as they are on disk.
async function noFilters(exec, root) {
  const r = await exec("git", [...READ, "config", "--get-regexp", "^filter\\..*\\.(clean|process)$"], { cwd: root });
  const names = new Set(r.stdout.split("\n").map((l) => /^filter\.(.+)\.(?:clean|process) /.exec(l)?.[1]).filter(Boolean));
  return [...names].flatMap((n) => ["-c", `filter.${n}.clean=`, "-c", `filter.${n}.process=`, "-c", `filter.${n}.required=false`]);
}

/** Paths that differ between two snapshot trees. */
async function changedPaths(exec, root, store, from, to) {
  const out = await git(exec, root, [alternates(store)], ["diff", "--name-only", "-z", "--no-renames", from, to]);
  return out.split("\0").filter(Boolean);
}

// The ignored files can never be in a snapshot, so a write to them cannot race one. Past a few
// hundred paths, it is taken as a race rather than checked.
async function anyNotIgnored(exec, root, paths) {
  if (paths.length > 200) return true;
  const r = await exec("git", [...READ, "check-ignore", "--", ...paths], { cwd: root });
  if (r.code > 1) return true;
  const ignored = new Set(r.stdout.split("\n").filter(Boolean));
  return paths.some((p) => !ignored.has(p));
}

/**
 * @typedef {{ tree?: string, problem?: string, gitDir?: string, index?: string, noFilters?: string[] }} Base
 * @typedef {{ gen: number, dir: string, store: string, raceFrom: number, snapped: number, raced: boolean, judged: boolean,
 *   ended: boolean, base: Map<string, Base>, now: Map<string, { tree?: string, paths?: string[], problem?: string }> }} Turn
 */

// After this long, a write can no longer race a turn that has yet to start.
const KEEP_WRITES = 5000;

export class Turns {
  /**
   * @param {(cmd: string, args: string[], opts: { cwd: string }) => Promise<{ code: number, stdout: string, stderr: string }>} exec
   * @param {{ name?: string | null, clock?: () => number }} [opts] `name`: the tab's temp folder name.
   */
  constructor(exec, { name = null, clock = Date.now } = {}) {
    this.exec = exec; this.clock = clock;
    this.name = name && /^[\w-]+$/.test(name) ? name : null;
    this.scratch = null; this.next = 1; this.dirs = new Map();
    /** @type {Turn | null} the latest turn that changed something */
    this.current = null;
    /** @type {Turn | null} a started turn with no change yet */
    this.pending = null;
    this.writes = new Map(); this.queue = Promise.resolve();
  }

  // One step at a time: a start, an end, and a refresh never interleave.
  run(fn) {
    const step = this.queue.then(fn);
    this.queue = step.catch(() => {});
    return step;
  }

  // Made at the first turn, not when the pane opens: in a pane the mod.open launcher opened, a
  // command run from init never settled. A named folder is the pane's own, so a reopened or
  // reloaded pane replaces what the last copy left, and a closed pane leaves at most one turn
  // behind for the OS's temp cleanup.
  async ensureScratch() {
    if (this.scratch) return;
    const script = this.name
      ? 'd="${TMPDIR:-/tmp}"; d="${d%/}/herdr-reviewer-$1"; rm -rf "$d" && mkdir -p "$d" && printf %s "$d"'
      : 'd="${TMPDIR:-/tmp}"; mktemp -d "${d%/}/herdr-reviewer.XXXXXX"';
    this.scratch = (await this.must("sh", ["-c", script, "sh", this.name ?? ""])).trim();
  }

  /** A watched repo's `paths` changed at `at`; one changed as a turn starts may sit in its baseline. */
  wrote(root, at, paths) {
    const outside = paths.filter((p) => !/\/\.git(\/|$)/.test(p));
    if (!outside.length) return;
    this.writes.set(root, [...(this.writes.get(root) ?? []).filter((w) => w.at > at - KEEP_WRITES), { at, paths: outside }]);
  }

  // Whether a file that is not ignored changed from just before the turn's edge to just after its
  // snapshot. Settled once that window has passed; until then, judged again at each step.
  async judge(t) {
    if (!t || t.judged) return;
    for (const root of t.base.keys()) {
      const paths = (this.writes.get(root) ?? []).filter((w) => w.at >= t.raceFrom && w.at <= t.snapped + RACE_AFTER).flatMap((w) => w.paths);
      if (paths.length && (await anyNotIgnored(this.exec, root, paths))) t.raced = true;
    }
    t.judged = t.raced || this.clock() > t.snapped + RACE_AFTER;
  }

  start(root, at) {
    return this.run(async () => {
      // An end the pane never saw: the old turn's changes so far are all it gets.
      if (this.current && !this.current.ended) this.freeze(this.current, await this.measure(this.current));
      if (this.pending) await this.drop(this.pending);
      await this.ensureScratch();
      const gen = this.next++, dir = `${this.scratch}/turn-${gen}`, store = `${dir}/objects`;
      await this.must("mkdir", ["-p", store]);
      this.dirs.set(gen, dir);
      const base = new Map();
      base.set(root, await this.baseOf(root, store, `${dir}/index`));
      this.pending = { gen, dir, store, raceFrom: at - RACE_BEFORE, snapped: this.clock(), raced: false, judged: false, ended: false, base, now: new Map() };
      await this.judge(this.pending);
    });
  }

  async baseOf(root, store, index) {
    try {
      const gitDir = (await git(this.exec, root, [], ["rev-parse", "--path-format=absolute", "--git-dir"])).trim();
      const b = { gitDir, index, noFilters: await noFilters(this.exec, root) };
      return { ...b, tree: await snapshot(this.exec, root, b, store) };
    } catch (e) { return { problem: why(e) === SPLIT ? SPLIT : `no turn snapshot: ${why(e)}` }; }
  }

  /** The tree of every snapshotted repo now, and the paths changed since the turn started. */
  async measure(t) {
    const now = new Map();
    await Promise.all([...t.base].map(async ([root, b]) => {
      if (!b.tree) { now.set(root, { problem: b.problem }); return; }
      try {
        const tree = await snapshot(this.exec, root, b, t.store);
        now.set(root, { tree, paths: await changedPaths(this.exec, root, t.store, b.tree, tree) });
      } catch (e) { now.set(root, { problem: why(e) }); }
    }));
    return now;
  }

  /** Brings the latest turn up to date; a waiting turn takes over once it changes something. */
  refresh() {
    return this.run(async () => {
      await this.judge(this.pending);
      if (this.pending) {
        const now = await this.measure(this.pending);
        if (changed(this.pending, now)) { await this.promote(now); return; }
      }
      // An ended turn keeps what it changed; later edits are not its own.
      if (this.current && !this.current.ended) {
        await this.judge(this.current);
        this.current.now = await this.measure(this.current);
      }
    });
  }

  /** The agents rested: the turn's changes become part of the session. */
  end() {
    return this.run(async () => {
      await this.judge(this.pending);
      if (this.pending) {
        const now = await this.measure(this.pending);
        if (!changed(this.pending, now)) { await this.drop(this.pending); return; }
        await this.promote(now);
        this.freeze(this.current, now);
      } else if (this.current && !this.current.ended) this.freeze(this.current, await this.measure(this.current));
    });
  }

  freeze(t, now) {
    t.now = now; t.ended = true;
  }

  async promote(now) {
    this.current = { ...this.pending, now };
    this.pending = null;
    await this.collect();
  }

  async drop(t) {
    if (this.pending === t) this.pending = null;
    await this.collect();
  }

  // Keeps the latest turn and a waiting one; comments retain their own quote text.
  async collect() {
    for (const [gen, dir] of this.dirs) {
      if (gen === this.current?.gen || gen === this.pending?.gen) continue;
      this.dirs.delete(gen);
      // Only folders this class made inside its own temp folder.
      if (dir.startsWith(`${this.scratch}/turn-`)) await this.exec("rm", ["-rf", dir], { cwd: this.scratch });
    }
  }

  async must(cmd, args) {
    const r = await this.exec(cmd, args, { cwd: "/" });
    if (r.code !== 0) throw new Error(`${cmd} failed: ${r.stderr.trim()}`);
    return r.stdout;
  }

  /** Latest turn for one repo; the caller supplies one root to start(). */
  last(root) {
    const t = this.current, b = t?.base.get(root), n = t?.now.get(root);
    if (!t) return { gen: null, problem: "no agent turn seen since the window opened" };
    if (!b) return { gen: t.gen, problem: "no turn snapshot for this repository" };
    if (t.raced) return { gen: t.gen, problem: "files changed just as the turn started, so this turn is not shown" };
    if (b.problem) return { gen: t.gen, problem: b.problem };
    if (n?.problem) return { gen: t.gen, problem: `no turn snapshot: ${n.problem}` };
    if (!n) return { gen: t.gen, problem: "turn snapshot not read yet" };
    return { gen: t.gen, from: b.tree, to: n.tree, objects: t.store };
  }
}

const why = (e) => (e instanceof Error ? e.message : String(e));
// A repo that stopped being readable counts as a change, so its reason shows; one unreadable
// since the turn started does not, unless no repo is readable at all.
const changed = (t, now) => [...now].some(([root, n]) => n.paths?.length || (n.problem && !t.base.get(root).problem))
  || (t.base.size > 0 && [...t.base.values()].every((b) => b.problem));
