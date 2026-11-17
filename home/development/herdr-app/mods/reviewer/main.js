// Vendored into this repo (Issue #2981). Pinned sources:
//   base:  https://github.com/vytasgavelis/herdr-reviewer
//          01e6d108a8fcc6aeaa07df5c068af59bdd642117 (mods/reviewer/)
//   donor: https://github.com/gfronza/herdr-app-reviewer
//          c219fda115336d3db796b81717a2f2139b223e86 (mods/reviewer/turns.js)
// Local changes (plan/2026-11-17-2981-herdr-app-diff-comments.md; filled in as steps land):
//   - mod.json: "focusable": true.
//   - Step 4: private-index turn snapshots, snapshot-backed preview and always-mounted tracker.
//   - Step 7: session-keyed turn drafts, full-quote stale checks and earlier-turn selection.
//   - Step 3: git is read-only (no committing, message input or button), no "Last commit" scope, no agent send
//     or start; scopes are Uncommitted, Branch, Last agent turn (stub until turns.js), Commit.
//
// Modified from Herdr's shipped "changes" mod (0.1.8), Apache License 2.0.
// Changes by Vytas Gavelis, MIT License. See LICENSE and THIRD-PARTY-NOTICES.
//
// Changes, for code review: the diff rows are syntax colored (highlight.js,
// palette.js), and the diff is reviewed like a pull request: click a line
// (two clicks for a range, a @@ header for its hunk) to open the comment
// box, add the comment, and it sits inline under those lines; comments can be
// added on several files; the comment icon on a file row comments on the
// file as a whole (an image, a deleted file). "Submit
// review" sends every comment with its
// lines as one message in the send dialog (ask.js); right-click a line to
// ask about it at once instead. Esc closes the comment box.
// The comment box is a card floating over the top-right of the diff (a
// strip under it when the panel is narrow), so the rows never move: a
// list row may hold no input, so the box can't sit between the lines.
// The unchanged lines between hunks (and before the first, after the
// last) are read from the file and folded into a "N unchanged lines" row:
// a click opens that fold, and "Full file" in the header opens them all
// (remembered in shared "reviewer.full"), so the whole file scrolls.
// Keys: "reviewer.submit", "reviewer.ask" (about the whole
// diff), "reviewer.clear" (drops the draft comments), "reviewer.full"
// (folds or unfolds the unchanged lines); in the send
// dialog (dialog.js) "reviewer.send" and "reviewer.close".
// Another mod opens a file's diff by setting shared "reviewer.open" to
// { id, at: Date.now(), path (absolute), on (machine or null), ref? }: the panel
// picks it up on its next refresh, selects the file (or notes that it has no
// diff in the shown scope) and clears the key. `path` may be the repo folder
// itself, to select no file; `ref` (a commit-ish) switches to reviewing that
// commit on its own first. A request older than OPEN_TTL
// is dropped unread, so a stale one never fires when the repo gets focus later.
// The header's scope picker chooses what is reviewed: the uncommitted
// changes, everything on the branch since it left its base (the pull-request
// view), the last agent turn, or any one commit from the log on its own;
// "reviewer.scope" cycles the first three.
// Props: { palette: "one-dark-pro" | "theme" | "dark-plus" (default: one-dark-pro),
//          font_size: px (default: the terminal's font size minus one),
//          base: the branch reviews are against (default: origin/HEAD, else main, else master) }.
import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex, TextareaState, Textarea, Scrollbar, v_virtual_list, VirtualListScrollHandle, Popover } from "gpui-base";
import { spaces, panes, agents, focused, exec, readTextFile, watchFolder, openOverlay, theme, settings, nextCommand, props, shared, setShared } from "herdr";
import { tokenize, languageOf } from "./highlight.js";
import { ask } from "./ask.js";
import { palette } from "./palette.js";
import { Dialog } from "./dialog.js";
import { Turns, createTracker, workState, READ, alternates, turnFor } from "./turns.js";
import { commentState } from "./stale.js";

const SESSION = `${Date.now().toString(36)}${Math.random().toString(36).slice(2)}`;

function location() {
  const space = spaces().find((s) => s.active), f = focused();
  const pane = f?.pane ? panes().find(p => p.pane === f.pane) : null;
  const on = f?.pane === null ? (f.terminal?.includes("/") ? f.terminal.split("/")[0] : null) : space?.machine ?? null;
  return { cwd: pane?.cwd || f?.cwd || space?.folder, on };
}
const key = () => JSON.stringify(location());
const countLines = (text) => text ? text.split("\n").length - Number(text.endsWith("\n")) : 0;
const NONE = "#00000000", DRAFTS = "reviewer.drafts", SCOPE = "reviewer.scope";
// The review scopes, in picker order; "commit" (one picked commit vs its
// parent) is chosen from the log, not cycled; "turn" is the last agent turn. A scope's id is its name, or
// "commit:<sha>" for a picked commit: the id keys the remembered scope and the drafts.
const SCOPES = ["work", "branch", "turn", "commit"];
const LOG_SIZE = 100;
const OPEN = "reviewer.open", OPEN_TTL = 30_000, FULL = "reviewer.full", TURNS = "reviewer.turns";
const gitRead = (args, opts, env = []) => exec(env.length ? "env" : "git", env.length ? [...env, "git", ...READ, ...args] : [...READ, ...args], opts);
// Diff lines shown at most; with the unchanged lines filled in, file lines at
// most (a bigger file shows its hunks only). A fold this short is just shown.
const DIFF_LINES = 1500, FILE_LINES = 30000, FILE_BYTES = 2_000_000, SHORT_GAP = 2;
// The code font: the terminal's (`font` in settings, JetBrains Mono when
// unset), one size smaller than the terminal (`font_size`, 14 when unset);
// `props.font_size` overrides. Rows and widths scale with it.
const codeFont = () => (typeof settings().font === "string" && settings().font) || "JetBrains Mono";
const codeSize = () => Number(props()?.font_size) || Math.max(9, (Number(settings().font_size) || 14) - 1);
const rowOf = (size) => Math.round(size * 1.8);
const charOf = (size) => size * 0.62;

// A row's identity across reloads: its kind, number and text.
const desc = (r) => ({ kind: r.kind, number: r.number ?? null, text: r.text });
const descKey = (d) => `${d.kind}|${d.number}|${d.text}`;

// Numbers each diff line once and tokenizes it, so a frame only draws the rows on screen.
// A line starting with "=" is an unchanged line outside the hunks (filled
// in by fillGaps): a context row with `gap` set to its run's number and no hunk.
// The new side (context, added, unchanged) and the removed lines each keep
// their own tokenizer state, so a comment opened in one isn't carried into the other.
function diffRows(lines, lang) {
  let old = 1, next = 1, state = null, oldState = null, hunk = -1, gap = -1, inGap = false;
  return lines.map((line, i) => {
    const match = /^@@ -(\d+)(?:,\d+)? \+(\d+)/.exec(line);
    if (match) { old = +match[1]; next = +match[2]; oldState = null; hunk = i; inGap = false; return { kind: "@", text: line, hunk: i, spans: [{ text: line, cls: "" }] }; }
    const kind = line[0];
    let row;
    if (kind === "=") { if (!inGap) { gap++; inGap = true; } old++; row = { kind: " ", number: next++, text: line.slice(1) || " ", gap }; }
    else if (kind === "-") row = { kind, number: old++, text: line.slice(1) || " " };
    else if (kind === "+") row = { kind, number: next++, text: line.slice(1) || " " };
    else if (kind === " ") { old++; row = { kind, number: next++, text: line.slice(1) || " " }; }
    else row = { kind: "", text: line };
    if (kind !== "=") inGap = false;
    row.hunk = kind === "=" ? -1 : hunk;
    const removed = kind === "-", t = tokenize(row.text.replace(/\t/g, "    "), lang, removed ? oldState : state);
    row.spans = t.spans;
    if (removed) oldState = t.state; else if (row.kind) state = t.state;
    return row;
  });
}

// The diff's lines with the file's unchanged lines around and between the
// hunks added as "=" lines. `text` is the new side of the file. Returns the
// diff as it was when the file doesn't match it (changed since the diff
// was read) or is too big.
function fillGaps(lines, text) {
  if (text.length > FILE_BYTES || text.includes("\0")) return lines;
  const file = text === "" ? [] : text.replace(/\n$/, "").split("\n");
  if (file.length > FILE_LINES) return lines;
  const out = [];
  let next = 1;
  for (const line of lines) {
    const match = /^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))?/.exec(line);
    if (match) {
      // An empty new side ("+12,0") starts after line 12, not at it.
      const start = match[2] === "0" ? +match[1] + 1 : +match[1];
      if (start < next) return lines;
      for (; next < start; next++) out.push(`=${file[next - 1]}`);
    } else if (line[0] === "+" || line[0] === " ") {
      if (file[next - 1] !== line.slice(1)) return lines;
      next++;
    }
    out.push(line);
  }
  for (; next <= file.length; next++) out.push(`=${file[next - 1]}`);
  return out;
}

export default class Changes extends View {
  init(_props, cx) {
    if (props()?.turns) { this.initTracker(cx); return; }
    // Opened as the send dialog (ask.js): this copy is the dialog, nothing else.
    if (props()?.dialog) { this.dialog = Object.create(Dialog.prototype); this.dialog.init(_props, cx); return; }
    this.files = []; this.rows = []; this.index = new Map(); this.items = []; this.sizes = []; this.diffWidth = 0; this.gutter = 30;
    this.comments = []; this.composer = null; this.handle = cx.focus_handle(); this.scroll = VirtualListScrollHandle.new();
    this.fontSize = codeSize(); this.row = rowOf(this.fontSize); this.unfolded = new Set();
    this.scope = "work"; this.sha = null; this.scopeInfo = null; this.choosingScope = false; this.range = ["HEAD"]; this.log = null;
    this.note = TextareaState.new({ placeholder: "Leave a comment on these lines…", rows: 4 });
    this.note.set_auto_grow(4, 14);
    // Enter adds; shift-enter is the textarea's own newline, so its submit is ignored.
    this.note.on("submit", (e, cx) => { if (!e?.shift) this.addComment(cx); });
    this.note.on("change", (_e, cx) => { this.noteText = this.note.value(); if (this.composer?.editing) this.rebuild(); cx.notify(); });
    this.noteText = "";
    // A request left by a previous app session must never replay.
    setShared("reviewer.send", null);
    this.refresh(cx);
    cx.timer.every(10000, (cx) => this.refresh(cx));
    cx.spawn(async (cx) => {
      for (;;) {
        const c = await nextCommand();
        if (c === "ask") this.askAbout(null, cx);
        else if (c === "submit") this.submit(cx);
        else if (c === "clear") this.setComments([], cx);
        else if (c === "scope") this.cycleScope(cx);
        else if (c === "full") this.toggleFull(cx);
        cx.notify();
      }
    });
  }

  initTracker(cx) {
    this.trackers = new Map();
    setShared(TURNS, {});
    cx.timer.every(250, (cx) => {
      const byTab = new Map();
      for (const agent of agents()) byTab.set(agent.tab, [...(byTab.get(agent.tab) ?? []), agent]);
      for (const [tab, group] of byTab) {
        let entry = this.trackers.get(tab);
        if (!entry) {
          entry = { edge: createTracker(), turns: null, root: null, on: spaces().find(s => s.id === group[0].space)?.machine ?? null };
          this.trackers.set(tab, entry);
        }
        const state = workState(group.map(a => a.status)), transition = entry.edge(state);
        if (transition.started) cx.spawn(async (cx) => {
          const pane = panes().find(p => p.pane === group[0].pane), cwd = pane?.cwd;
          if (!cwd) return;
          const top = await gitRead(["rev-parse", "--show-toplevel"], { cwd, on: entry.on });
          if (top.code !== 0) return;
          const root = top.stdout.trim();
          if (entry.root !== root) {
            entry.watch?.cancel();
            entry.root = root;
            entry.turns = new Turns((cmd, args, opts) => exec(cmd, args, { ...opts, on: entry.on }), { name: tab.replace(/[^\w-]/g, "-") });
            entry.turnsId = Math.random().toString(36).slice(2);
            this.watchTurn(tab, entry, root, cx);
          }
          await entry.turns.start(root, Date.now());
          this.publishTurn(tab, entry); cx.notify();
        });
        if (transition.ended && entry.turns) cx.spawn(async (cx) => {
          await entry.turns.end(); this.publishTurn(tab, entry); cx.notify();
        });
      }
      for (const [tab, entry] of this.trackers) if (!byTab.has(tab) && entry.edge("resting").ended && entry.turns) {
        cx.spawn(async (cx) => { await entry.turns.end(); this.publishTurn(tab, entry); cx.notify(); });
      }
    });
  }

  watchTurn(tab, entry, root, cx) {
    cx.spawn(async (cx) => {
      try {
        while (this.trackers.get(tab) === entry && entry.root === root) {
          const pending = watchFolder(root);
          entry.watch = pending;
          const paths = await pending;
          if (entry.root !== root) break;
          if (paths.length) {
            entry.turns.wrote(root, Date.now(), paths);
            await entry.turns.refresh();
            this.publishTurn(tab, entry); cx.notify();
          }
        }
      } catch { /* A later turn can start a fresh watch. */ }
    });
  }

  publishTurn(tab, entry) {
    const last = entry.turns.last(entry.root);
    setShared(TURNS, { ...(shared(TURNS) ?? {}), [tab]: { root: entry.root, on: entry.on,
      last: { ...last, gen: last.gen === null ? null : `${entry.turnsId}:${last.gen}` } } });
  }

  watch(root, cx) {
    if (this.on || this.watched === root) return;
    this.watched = root;
    cx.spawn(async (cx) => {
      try {
        while (this.watched === root) {
          await watchFolder(root);
          if (this.watched === root) this.refresh(cx);
        }
      } catch { this.watched = null; }
    });
  }

  refresh(cx) {
    if (this.loading || this.busy) return;
    const { cwd, on } = location(), context = key(), request = shared(OPEN);
    // The request this refresh answers; render never starts another refresh
    // for the same id, so a repo whose git keeps failing is read once, not in a loop.
    this.tried = request?.id ?? this.tried;
    if (context !== this.context) {
      this.context = context; this.root = null; this.log = null; this.files = []; this.open = null; this.comments = []; this.composer = null;
      this.setLines([]); this.error = null; this.note_ = null; this.watched = null; this.closed = false; this.limited = false;
    }
    if (!cwd) return;
    this.loading = true;
    cx.spawn(async (cx) => {
      try {
        const top = await exec("git", [...READ, "rev-parse", "--show-toplevel"], { cwd, on });
        if (key() !== context) return;
        if (top.code !== 0) { this.root = null; this.files = []; this.setLines([]); this.open = null; this.error = "Not a git repository"; return; }
        const root = top.stdout.trim(), git = (args) => exec("git", [...READ, ...args], { cwd: root, on });
        const status = await git(["status", "--porcelain=v1", "-z", "--no-renames", "--untracked-files=all"]);
        if (status.code !== 0) throw new Error(status.stderr);
        const head = await git(["rev-parse", "--verify", "HEAD"]);
        const hasHead = head.code === 0;
        // The scope in use (remembered per repo), and what this repo offers.
        // A request for a commit (`ref`) picks that commit's scope, as a click in the list would.
        const scopeKey = `${on ?? ""}:${root}`, requested = this.requestedFile(request, root, on);
        let wanted = null, refNote = null;
        if (requested !== null && typeof request.ref === "string" && request.ref) {
          const r = hasHead && !request.ref.startsWith("-") ? await git(["rev-parse", "--verify", "-q", `${request.ref}^{commit}`]) : null;
          if (r?.code === 0) { wanted = r.stdout.trim(); setShared(SCOPE, { ...(shared(SCOPE) ?? {}), [scopeKey]: `commit:${wanted}` }); }
          else refNote = `Requested commit ${request.ref} isn't in this repo.`;
        }
        const remembered = (shared(SCOPE) ?? {})[scopeKey];
        let [scope, sha] = wanted ? ["commit", wanted] : root === this.root ? [this.scope, this.sha] : remembered?.startsWith("commit:") ? ["commit", remembered.slice(7)] : [remembered ?? null, null];
        const info = hasHead ? await this.scopes(git, scope === "commit" ? sha : null) : { branch: null, base: null, merge: null, turn: null, commit: null };
        info.turn = turnFor(shared(TURNS), focused()?.tab, root, on);
        const turnEnv = info.turn?.objects ? [alternates(info.turn.objects)] : [];
        if (!scope) scope = info.merge ? "branch" : "work";
        if (scope === "branch" && !info.merge) scope = "work";
        if (scope === "commit" && !info.commit) { scope = "work"; sha = null; }
        if (scope !== "commit") sha = null;
        // What is diffed: the working tree against one ref, or a picked commit against its parent.
        const range = scope === "commit" ? [info.commit.parent, info.commit.sha]
          : scope === "turn" ? (info.turn?.from && info.turn?.to ? [info.turn.from, info.turn.to] : [])
          : [scope === "branch" ? info.merge : "HEAD"];
        const diffGit = (args) => gitRead(args, { cwd: root, on }, scope === "turn" ? turnEnv : []);
        // Files: what differs in the range, plus (for the working tree) untracked files and conflicts from the status.
        const stats = {}, changed = new Map();
        const results = scope === "turn" && !range.length ? [] : hasHead ? [await diffGit(["diff", ...range, "--numstat", "-z", "--no-renames"])] : [await git(["diff", "--cached", "--numstat", "-z", "--no-renames"]), await git(["diff", "--numstat", "-z", "--no-renames"])];
        for (const result of results) {
          if (result.code !== 0) throw new Error(result.stderr);
          for (const entry of result.stdout.split("\0")) {
            const [a, d, ...parts] = entry.split("\t");
            if (!parts.length) continue;
            const path = parts.join("\t"), old = stats[path] ?? { add: 0, del: 0 };
            stats[path] = { add: old.add + (Number(a) || 0), del: old.del + (Number(d) || 0), binary: a === "-" };
          }
        }
        if (hasHead) {
          const names = scope === "turn" && !range.length ? { code: 0, stdout: "" } : await diffGit(["diff", ...range, "--name-status", "-z", "--no-renames"]);
          if (names.code !== 0) throw new Error(names.stderr);
          const parts = names.stdout.split("\0");
          // With diff.autoRefreshIndex off, a file whose stat changed but whose
          // content did not (touched, rewritten unchanged) is listed as M here
          // with no numstat line, until something else refreshes the index.
          for (let i = 0; i + 1 < parts.length && parts[i]; i += 2) { if (parts[i][0] !== "M" || stats[parts[i + 1]]) changed.set(parts[i + 1], parts[i][0]); }
        }
        // A picked commit is history: the working tree's state is not part of it.
        const entries = scope === "commit" || scope === "turn" ? [] : status.stdout.split("\0").filter(Boolean);
        for (const entry of entries) {
          const xy = entry.slice(0, 2), path = entry.slice(3);
          if (xy === "??") changed.set(path, "?");
          else if (xy.includes("U") || xy === "AA" || xy === "DD") changed.set(path, "U");
          else if (!hasHead) changed.set(path, xy.includes("D") ? "D" : xy.includes("A") ? "A" : "M");
        }
        const files = [];
        for (const [path, s0] of [...changed.entries()].sort((a, b) => a[0].localeCompare(b[0])).slice(0, 1000)) {
          const fresh = s0 === "?", s = fresh ? "A" : s0 === "D" || s0 === "A" || s0 === "U" ? s0 : "M";
          const stat = stats[path] ?? { add: 0, del: 0 };
          files.push({ path, status: s, fresh, ...stat });
        }
        if (key() !== context) return;
        if (root !== this.root || scope !== this.scope || sha !== this.sha || range.join(" ") !== this.range.join(" ")) { this.setLines([]); }
        const changedSet = root !== this.root || scope !== this.scope || sha !== this.sha;
        this.root = root; this.on = on; this.hasHead = hasHead; this.scope = scope; this.sha = sha; this.scopeInfo = info; this.range = range;
        // Each scope keeps its own comments: switching swaps the set, the others stay saved.
        if (changedSet || (scope === "turn" && this.turnGen !== info.turn?.gen)) { this.comments = this.loadDrafts(this.scopeId()); this.composer = null; }
        this.turnGen = info.turn?.gen;
        for (const path of new Set(this.comments.map((c) => c.path))) {
          if (!files.some((f) => f.path === path)) files.push({ path, status: "", add: 0, del: 0, noLongerChanged: true });
        }
        this.files = files; this.limited = changed.size > 1000; this.error = scope === "turn" ? info.turn?.problem ?? null : null;
        this.watch(root, cx);
        if (requested !== null) {
          // "": the repo itself, no file to select.
          if (requested !== "") {
            this.open = files.some(f => f.path === requested) ? requested : null;
            this.closed = !this.open; this.composer = null; this.note_ = this.open ? null : "Requested file has no diff in this scope (or is outside the first 1,000 files).";
            this.setLines([]);
            if (this.open) this.scroll.scroll_to_item(0);
          } else this.note_ = null;
          if (refNote) this.note_ = refNote;
          if (shared(OPEN)?.id === request.id) setShared(OPEN, null);
        }
        if (this.open && !files.some((f) => f.path === this.open)) { this.open = null; this.setLines([]); }
        // The first file's diff shows until you pick another.
        if (!this.open && !this.closed && files.length) this.open = files[0].path;
        if (this.open) {
          try { await this.load(this.open, context); }
          catch { if (key() === context) this.setLines(["Cannot preview this diff (too large or unreadable)"]); }
        }
        await this.checkComments();
      } catch (e) { if (key() === context) this.error = String(e); }
      finally { this.loading = false; cx.notify(); }
    });
  }

  // A request's path relative to the repo `root` on machine `on` ("" for the
  // repo folder itself), or null when it is not for that repo and machine (or
  // is stale). Windows paths compare case-insensitively.
  requestedFile(request, root0 = this.root, on = this.on) {
    if (!root0 || this.stale(request) || typeof request.path !== "string" || (request.on ?? null) !== (on ?? null)) return null;
    const windows = !on && /^[A-Za-z]:[\\/]/.test(root0);
    const root = (windows ? root0.replaceAll("\\", "/") : root0).replace(/\/$/, ""), path = (windows ? request.path.replaceAll("\\", "/") : request.path).replace(/\/$/, "");
    const fold = (s) => windows ? s.toLowerCase() : s;
    if (fold(path) === fold(root)) return "";
    return fold(path).startsWith(fold(root) + "/") ? path.slice(root.length + 1) : null;
  }
  // Malformed, or older than OPEN_TTL: dropped, whichever repo it was for.
  stale(request) {
    return typeof request?.id !== "string" || !request.id || typeof request.at !== "number" || Date.now() - request.at > OPEN_TTL;
  }

  // The shown scope's id: its name, or "commit:<sha>" for a picked commit.
  scopeId(scope = this.scope, sha = this.sha) { return scope === "commit" ? `commit:${sha}` : scope; }
  // The draft comments of one scope (by id) of the shown repo. Drafts saved before
  // scopes existed (keyed by repo alone) were all on the uncommitted changes.
  draftKey(id = this.scopeId()) {
    return `${this.on ?? ""}:${this.root}:${id === "turn" ? `turn:${SESSION}:${this.scopeInfo?.turn?.gen ?? 0}` : id}`;
  }
  loadDrafts(id) {
    const drafts = { ...(shared(DRAFTS) ?? {}) }, old = `${this.on ?? ""}:${this.root}`;
    if (drafts[old]) { drafts[`${old}:work`] = [...(drafts[`${old}:work`] ?? []), ...drafts[old]]; delete drafts[old]; setShared(DRAFTS, drafts); }
    return drafts[this.draftKey(id)] ?? [];
  }

  // What this repo can be reviewed against: its branch, the base branch
  // (props.base, else origin/HEAD, else main, else master), the merge
  // base with it (null when on the base itself), and the picked commit `sha` (null when it is gone).
  async scopes(git, sha) {
    const out = async (args) => { const r = await git(args); return r.code === 0 ? r.stdout.trim() : null; };
    const branch = await out(["rev-parse", "--abbrev-ref", "HEAD"]);
    let base = typeof props()?.base === "string" ? props().base : null;
    if (!base) { const h = await out(["symbolic-ref", "-q", "refs/remotes/origin/HEAD"]); if (h) base = h.replace(/^refs\/remotes\/origin\//, ""); }
    if (!base) for (const b of ["main", "master"]) { if (await out(["rev-parse", "--verify", "-q", `refs/heads/${b}`]) !== null) { base = b; break; } }
    let merge = null;
    if (base && branch !== base) {
      const baseRef = (await out(["rev-parse", "--verify", "-q", `refs/heads/${base}`])) !== null ? base : `origin/${base}`;
      merge = await out(["merge-base", baseRef, "HEAD"]);
      if (merge && (await out(["rev-parse", "HEAD"])) === merge) merge = null;
    }
    let commit = null;
    if (sha) {
      const found = await out(["log", "-1", "--format=%H%x1f%h%x1f%s", `${sha}^{commit}`, "--"]);
      if (found) {
        const [full, short, title] = found.split("\x1f");
        // A root commit is diffed against the empty tree.
        const parent = (await out(["rev-parse", "--verify", "-q", `${full}~1`])) ?? (await out(["hash-object", "-t", "tree", "/dev/null"]));
        if (parent) commit = { sha: full, short, subject: title, parent };
      }
    }
    return { branch, base, merge, turn: null, commit };
  }

  // The scope's name for the header and the submit message.
  scopeLabel(scope = this.scope) {
    const i = this.scopeInfo ?? {};
    return scope === "branch" ? `vs ${i.base}` : scope === "turn" ? "Last agent turn" : scope === "commit" ? `Commit ${i.commit?.short ?? ""}` : "Uncommitted";
  }
  scopeWords() {
    const i = this.scopeInfo ?? {};
    return this.scope === "branch" ? `all changes on branch ${i.branch} since it left ${i.base} (merge base ${(i.merge ?? "").slice(0, 7)}), committed or not`
      : this.scope === "turn" ? "what the agent changed in its last turn"
      : this.scope === "commit" ? `commit ${i.commit?.short}${i.commit?.subject ? ` ("${i.commit.subject}")` : ""} on its own, against its parent`
      : "uncommitted changes";
  }
  // `sha`: the commit, for the "commit" scope.
  setScope(scope, cx, sha = null) {
    const id = this.scopeId(scope, sha);
    if (!this.root || id === this.scopeId()) { this.choosingScope = false; cx.notify(); return; }
    const all = { ...(shared(SCOPE) ?? {}) }; all[`${this.on ?? ""}:${this.root}`] = id; setShared(SCOPE, all);
    this.scope = scope; this.sha = sha; this.choosingScope = false; this.composer = null; this.setLines([]);
    this.comments = this.loadDrafts(id); this.rebuild();
    this.refresh(cx); cx.notify();
  }
  // From a picked commit, the next scope is Uncommitted.
  cycleScope(cx) {
    const ok = SCOPES.slice(0, 3).filter((s) => s !== "branch" || this.scopeInfo?.merge);
    this.setScope(ok[(ok.indexOf(this.scope) + 1) % ok.length], cx);
  }
  // The commits for the picker, read when it opens: on a branch that has left
  // its base, the branch's own (first-parent, since the merge base); else the
  // last LOG_SIZE on HEAD. First-parent: commits merged in show as their merge.
  loadLog(cx) {
    const root = this.root, on = this.on, context = this.context, merge = this.scopeInfo?.merge;
    if (!root || !this.hasHead) return;
    cx.spawn(async (cx) => {
      const r = await exec("git", [...READ, "log", "--first-parent", `-n${LOG_SIZE}`, "--format=%H%x1f%h%x1f%s%x1f%ar%x1f%an", ...(merge ? [`${merge}..HEAD`] : []), "--"], { cwd: root, on });
      if (key() !== context || root !== this.root) return;
      this.log = r.code !== 0 ? [] : r.stdout.split("\n").filter(Boolean).map((l) => { const [sha, short, subject, when, author] = l.split("\x1f"); return { sha, short, subject, when, author }; });
      cx.notify();
    });
  }

  async readRows(path) {
    const file = this.files.find((f) => f.path === path), root = this.root, on = this.on;
    if (!file) return null;
    let lines;
    if (this.scope !== "turn" && (file.fresh || (!this.hasHead && file.status === "A"))) {
      const text = await readTextFile(`${root}/${path}`, { on }).catch(() => null);
      if (text === null) lines = ["Cannot preview this file (binary, too large, or unreadable)"];
      else if (text.includes("\0")) lines = ["Binary file · no text diff"];
      else {
        file.add = countLines(text);
        lines = [`@@ -0,0 +1,${file.add} @@`, ...text.slice(0, 400000).replace(/\n$/, "").split("\n").slice(0, 1500).map(l => `+${l}`)];
      }
    } else {
      const range = this.hasHead ? this.range : [];
      const env = this.scope === "turn" && this.scopeInfo?.turn?.objects ? [alternates(this.scopeInfo.turn.objects)] : [];
      const r = await gitRead(["diff", ...range, "--no-ext-diff", "--no-textconv", "--no-color", "--", path], { cwd: root, on }, env);
      if (r.code !== 0) throw new Error(r.stderr);
      const all = r.stdout.replace(/\n$/, "").split("\n"), first = all.findIndex((l) => l.startsWith("@@"));
      lines = first < 0 ? [file.binary ? "Binary file changed" : "No text diff available"] : all.slice(first);
      // The unchanged lines around the hunks, from the new side of the file:
      // the picked commit's blob, else the working tree. A cut diff or a deleted file has none.
      if (first >= 0 && lines.length <= DIFF_LINES && file.status !== "D") {
        const commit = (this.scope === "commit" || this.scope === "turn") && range.length === 2 ? range[1] : null;
        const text = commit ? await gitRead(["show", `${commit}:${path}`], { cwd: root, on }, env).then((s) => s.code === 0 ? s.stdout : null).catch(() => null)
          : await readTextFile(`${root}/${path}`, { on }).catch(() => null);
        if (typeof text === "string") lines = fillGaps(lines, text);
      }
    }
    if (lines.length > (lines.some((l) => l[0] === "=") ? FILE_LINES + DIFF_LINES : DIFF_LINES)) lines = lines.slice(0, DIFF_LINES);
    return lines.map(line => line.length > 4000 ? line.slice(0, 4000) + "… (line truncated)" : line);
  }

  async load(path, context) {
    const lines = await this.readRows(path);
    if (lines && key() === context && this.open === path) this.setLines(lines, path);
  }

  async checkComments() {
    const context = this.context, scope = this.draftKey(), results = new Map();
    for (const path of new Set(this.comments.filter((c) => !c.whole).map((c) => c.path))) {
      let rows = null;
      if (this.files.some((f) => f.path === path)) {
        try { rows = diffRows(await this.readRows(path), languageOf(path)); } catch { /* An unreadable file cannot confirm a quote. */ }
      }
      for (const c of this.comments.filter((c) => c.path === path)) {
        results.set(c.id, this.scope === "turn" && (!this.scopeInfo?.turn?.objects || !scope.includes(`turn:${SESSION}:`))
          ? "not rechecked" : commentState(c, rows, (r) => this.quote(r)));
      }
    }
    if (context === this.context && scope === this.draftKey()) { this.commentStates = results; this.rebuild(); }
  }

  setLines(lines, path) {
    const same = this.lines && lines.length === this.lines.length && lines.every((l, i) => l === this.lines[i]);
    if (same) return;
    if (path !== this.linesPath) this.unfolded = new Set();
    this.lines = lines; this.linesPath = path;
    this.rows = diffRows(lines, languageOf(path));
    // Each fold's rows, by gap number.
    this.gaps = [];
    this.rows.forEach((r, i) => { if (r.gap !== undefined) (this.gaps[r.gap] ??= []).push(i); });
    this.index = new Map();
    this.rows.forEach((r, i) => { const k = descKey(desc(r)); if (!this.index.has(k)) this.index.set(k, i); });
    this.measure();
  }

  // Sizes that depend on the font: the gutter (wide enough for the largest
  // line number), the diff's width, and the rows.
  measure() {
    const ch = charOf(this.fontSize), digits = String(Math.max(0, ...this.rows.map((r) => r.number ?? 0))).length;
    this.gutter = Math.max(30, Math.ceil(digits * ch + 10));
    this.diffWidth = Math.max(300, ...(this.lines ?? []).map((line) => Math.ceil(line.length * ch) + this.gutter + 36));
    this.rebuild();
  }

  // Where a row descriptor is in the current diff, or -1.
  at(d) { return d ? (this.index.get(descKey(d)) ?? -1) : -1; }

  // Whether a fold shows its lines: "Full file", opened by a click, too short
  // to fold, or holding lines that a comment or the comment box is on.
  shown(g, keep) {
    return this.full() || this.unfolded.has(g) || (this.gaps[g]?.length ?? 0) <= SHORT_GAP || keep.has(g);
  }
  full() { return shared(FULL) === true; }
  toggleFull(cx) { setShared(FULL, !this.full()); this.unfolded = new Set(); this.rebuild(); cx.notify(); }
  unfold(g, cx) { this.unfolded.add(g); this.rebuild(); cx.notify(); }

  // The list's items: diff rows, with each comment under its last line;
  // comments on the whole file come first. The comment being edited stays
  // in place as a live preview of what is typed in the box. A closed fold
  // is one "N unchanged lines" item in place of its rows.
  rebuild() {
    // Folds a comment or the comment box reaches into stay open.
    const keep = new Set(), reach = (from, to) => { for (let j = Math.max(0, from); j <= to; j++) { const g = this.rows[j]?.gap; if (g !== undefined) keep.add(g); } };
    for (const c of this.comments) if (c.path === this.open && !c.whole) reach(this.at(c.from), this.at(c.to));
    const target = this.target();
    if (target) reach(target.from, target.to);
    const items = [];
    this.builtFull = this.full();
    this.rows.forEach((r, i) => {
      if (r.gap === undefined || this.shown(r.gap, keep)) items.push({ key: `r:${i}`, kind: "row", i, height: this.row });
      else if (this.gaps[r.gap][0] === i) items.push({ key: `f:${r.gap}`, kind: "fold", gap: r.gap, count: this.gaps[r.gap].length, height: this.row });
    });
    const under = new Map(), editing = this.composer?.editing ?? null;
    this.items = [];
    for (const c of this.comments) {
      if (c.path !== this.open) continue;
      const live = c.id === editing, text = live ? this.noteText : c.text;
      const it = { key: `c:${c.id}`, kind: "comment", id: c.id, live, text, height: this.commentHeight(text) };
      if (c.whole) { this.items.push({ ...it, whole: true, from: -1, to: -1 }); continue; }
      const from = this.at(c.from), to = this.at(c.to);
      if (from < 0 || to < 0 || to < from) { this.items.push({ ...it, from: -1, to: -1 }); continue; }
      (under.get(to) ?? under.set(to, []).get(to)).push({ ...it, from, to });
    }
    for (const item of items) { this.items.push(item); if (item.kind === "row") for (const c of under.get(item.i) ?? []) this.items.push(c); }
    this.sizes = this.items.map((it) => it.height);
  }

  commentHeight(text) {
    const cpl = Math.max(24, Math.floor(((this.size?.width ?? 368) - 90) / charOf(this.fontSize)));
    const lines = text.split("\n").reduce((n, l) => n + Math.max(1, Math.ceil(l.length / cpl)), 0);
    return 44 + lines * Math.round(this.fontSize * 1.45);
  }
  // The composer's target rows in the current diff, or null (also for a whole-file comment).
  target() {
    if (!this.composer || this.composer.whole || this.composer.path !== this.open) return null;
    const from = this.at(this.composer.from), to = this.at(this.composer.to);
    return from < 0 || to < 0 ? null : { from: Math.min(from, to), to: Math.max(from, to) };
  }

  // Click on a diff row: open the comment box there, or widen it to a range.
  clickRow(i, cx) {
    const row = this.rows[i];
    if (!row || row.kind === "") return;
    let from = i, to = i;
    if (row.kind === "@") {
      const members = this.rows.map((r, j) => j).filter((j) => j !== i && this.rows[j].hunk === i && this.rows[j].kind !== "");
      if (!members.length) return;
      from = members[0]; to = members[members.length - 1];
    }
    const t = this.target();
    if (t && !this.composer.editing && !this.noteText.trim()) {
      // A click inside the highlighted lines clears them; outside, it widens them.
      if (from >= t.from && to <= t.to) { this.closeComposer(cx); return; }
      from = Math.min(t.from, from); to = Math.max(t.to, to);
    }
    // Editing a line comment keeps its identity when retargeted; a whole-file comment stays what it is.
    const editing = this.composer?.editing && !this.composer.whole && this.composer.path === this.open ? this.composer.editing : null;
    this.composer = { path: this.open, from: desc(this.rows[from]), to: desc(this.rows[to]), editing };
    this.openBox(cx);
  }

  // Opening the box: rebuild and give the textarea the keyboard (again
  // once the frame is drawn). The list is not scrolled: what was clicked
  // is on screen already, and a scroll would make the rows jump.
  // `scrollTo`: an item index to bring on screen anyway (a whole-file
  // comment, whose card is at the top of the diff).
  openBox(cx, scrollTo = -1) {
    this.rebuild();
    this.note.focus();
    if (scrollTo >= 0) this.scroll.scroll_to_item(scrollTo);
    cx.timer.after(300, () => this.note.focus());
    cx.notify();
  }

  // Comment on a file as a whole (an image, a deleted file, anything without lines to click).
  commentFile(path, cx) {
    if (this.composer?.whole && this.composer.path === path && !this.composer.editing && !this.noteText.trim()) { this.closeComposer(cx); return; }
    if (this.open !== path) this.pick(path, cx);
    this.composer = { path, whole: true, editing: null };
    this.openBox(cx, 0);
  }

  editComment(id, cx) {
    const c = this.comments.find((c) => c.id === id);
    if (!c) return;
    this.composer = c.whole ? { path: c.path, whole: true, editing: id } : { path: c.path, from: c.from, to: c.to, editing: id };
    this.note.set_value(c.text); this.noteText = c.text;
    this.openBox(cx);
  }

  closeComposer(cx) {
    this.composer = null; this.note.set_value(""); this.noteText = ""; this.rebuild(); this.handle.focus(); cx.notify();
  }

  setComments(list, cx) {
    this.comments = list; this.rebuild();
    const drafts = { ...(shared(DRAFTS) ?? {}) }, k = this.draftKey();
    if (list.length) drafts[k] = list; else delete drafts[k];
    setShared(DRAFTS, drafts);
    cx?.notify();
  }

  addComment(cx) {
    const text = this.note.value().trim(), c = this.composer;
    if (!c || !text) return;
    const list = this.comments.filter((x) => x.id !== c.editing);
    const id = c.editing ?? `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`;
    const comment = c.whole ? { id, path: c.path, whole: true, text } : { id, path: c.path, from: c.from, to: c.to, text };
    const t = this.target();
    if (t) { comment.from = desc(this.rows[t.from]); comment.to = desc(this.rows[t.to]); comment.quote = this.quote(this.rows.slice(t.from, t.to + 1)); }
    else if (c.editing) { const old = this.comments.find((x) => x.id === c.editing); if (old?.quote) comment.quote = old.quote; }
    if (this.scope === "turn") comment.session = SESSION;
    list.push(comment);
    this.setComments(list);
    cx.spawn(async (cx) => { await this.checkComments(); cx.notify(); });
    this.closeComposer(cx);
  }

  deleteComment(cx) {
    const id = this.composer?.editing;
    if (id) this.setComments(this.comments.filter((c) => c.id !== id));
    this.closeComposer(cx);
  }

  // The text the agent gets for a set of rows (indexes; null: every row of the open diff).
  quote(rows) {
    return rows.map((r) => r.kind === "@" ? r.text : `${r.number === undefined ? "" : String(r.number).padStart(5)} ${r.kind || " "} ${r.text}`).join("\n");
  }
  span(rows) {
    const nums = rows.filter((r) => r.number !== undefined && r.kind !== "-").map((r) => r.number), olds = rows.filter((r) => r.kind === "-").map((r) => r.number);
    const range = (a) => a.length > 1 ? `lines ${Math.min(...a)}-${Math.max(...a)}` : `line ${a[0]}`;
    return nums.length ? range(nums) : olds.length ? `removed ${range(olds)}` : "";
  }
  where(path) { return `${this.root}/${path}${this.on ? ` (on ${this.on})` : ""}`; }
  // A file's change in words, for a whole-file comment: "added, binary".
  describe(path) {
    const f = this.files.find((f) => f.path === path);
    if (!f) return "no longer changed";
    const what = f.status === "A" ? "added" : f.status === "D" ? "deleted" : f.status === "U" ? "conflict" : "modified";
    return f.binary ? `${what}, binary` : f.add || f.del ? `${what}, +${f.add} −${f.del}` : what;
  }

  askAbout(indexes, cx) {
    if (!this.open || !this.rows.length) return;
    // The whole diff: its hunks, not the unchanged lines filled in around them.
    const rows = (indexes ? indexes.sort((a, b) => a - b).map((i) => this.rows[i]) : this.rows.filter((r) => r.gap === undefined)).filter(Boolean).slice(0, 400);
    const span = this.span(rows), title = `${this.open}${span ? `:${span.replace(/^(removed )?lines? /, "")}` : ""}`;
    const head = indexes ? `In ${this.where(this.open)}, ${span || "these lines"} of the diff (${this.scopeWords()}; new-file line numbers; - lines are removed):` : `The diff of ${this.where(this.open)} (${this.scopeWords()}):`;
    cx.spawn(async (cx) => { try { await ask({ title, context: `${head}\n${this.quote(rows)}` }); } catch (e) { this.note_ = `Ask failed: ${e}`; } cx.notify(); });
  }

  // Every comment uses the quote saved when it was written, even if its file changed later.
  formatComments(list, states = new Map()) {
    list = [...list].sort((a, b) => a.path.localeCompare(b.path) || (a.from?.number ?? -1) - (b.from?.number ?? -1));
    const parts = list.map((c) => {
      if (c.whole) return `### ${c.path}, whole file (${this.describe(c.path)})\n\nComment: ${c.text}`;
      const span = c.from.number === c.to.number ? `line ${c.from.number}` : `lines ${c.from.number}-${c.to.number}`;
      const body = c.quote ?? (c.from.text === c.to.text ? `${String(c.from.number).padStart(5)} ${c.from.kind} ${c.from.text}` : `${String(c.from.number).padStart(5)} ${c.from.kind} ${c.from.text}\n      …\n${String(c.to.number).padStart(5)} ${c.to.kind} ${c.to.text}`);
      const stale = states.get(c.id) === "lines changed" ? "\n(the lines changed after this comment)" : "";
      const unchecked = states.get(c.id) === "not rechecked" ? "\n(not rechecked)" : "";
      return `### ${c.path}, ${span}${stale}${unchecked}\n${body}\n\nComment: ${c.text}`;
    });
    return parts.join("\n\n");
  }

  // Every comment, with its lines, as one review message.
  submit(cx) {
    if (!this.root) return;
    cx.spawn(async (cx) => {
    await this.checkComments();
    const list = [...this.comments], drafts = shared(DRAFTS) ?? {}, prefix = `${this.on ?? ""}:${this.root}:turn:`;
    const earlier = Object.entries(drafts).filter(([k, v]) => this.scope === "turn" && (k.startsWith(prefix) || k === `${this.on ?? ""}:${this.root}:turn`) && k !== this.draftKey() && v.length)
      .map(([key, comments]) => ({ key, ids: comments.map((c) => c.id), context: this.formatComments(comments, new Map(comments.map((c) => [c.id, "not rechecked"]))) }));
    if (!list.length && !earlier.length) return;
    const n = list.length, title = `Review · ${n} comment${n > 1 ? "s" : ""}`;
    const context = `Code review of ${this.root}${this.on ? ` (on ${this.on})` : ""}: ${this.scopeWords()}. ${n} comment${n > 1 ? "s" : ""}. Line numbers are new-file numbers; "-" lines are removed.\n\n${this.formatComments(list, this.commentStates)}`;
    const repo = this.root, scope = this.scopeId(), draftKey = this.draftKey();
      try {
        openOverlay({ mod: "reviewer", kind: "dialog", width: 680, height: 560,
          props: { dialog: true, title, context, repo, scope, earlier,
            drafts: list.length ? [{ key: draftKey, ids: list.map((c) => c.id) }] : [] } });
      } catch (e) { this.note_ = `Submit failed: ${e}`; }
      cx.notify();
    });
  }

  // The scope picker: a small select-looking box with the scope's name; a
  // Popover lists the scopes the repo offers, with a check on the current one.
  scopePicker(t) {
    const i = this.scopeInfo ?? {};
    const options = [
      { scope: "work", label: "Uncommitted", detail: "working tree vs HEAD", ok: true },
      { scope: "branch", label: i.base ? `vs ${i.base}` : "vs base branch", detail: i.merge ? `everything on ${i.branch} since it left ${i.base}` : i.base ? `on ${i.base} itself` : "no main or master branch", ok: Boolean(i.merge) },
      { scope: "turn", label: "Last agent turn", detail: i.turn?.gen ? "latest turn in this tab" : "no agent turn seen since the window opened", ok: true },
    ];
    const box = h_flex().id("scope-box").h(24).px(8).gap(6).items_center().rounded(6).border_1().border_color(this.choosingScope ? t.accent : t.border).bg(t.raised).cursor_pointer().hover((s) => s.bg(t.hover))
      .tooltip("What is reviewed: the uncommitted changes, the whole branch, the last agent turn, or one commit").child(div().text_size(12).child(this.scopeLabel())).child(svg("mods/reviewer/chevron-down.svg").size(11).text_color(t.dim));
    const check = (on) => on ? svg("mods/reviewer/check.svg").size(12).text_color(t.accent) : div().w(12);
    // The recent commits, newest first: a click reviews that commit on its own.
    const commits = (this.log ?? []).map((c) =>
      h_flex().id(`scope-commit-${c.sha}`).px(10).py(5).gap(8).items_center().rounded(6).cursor_pointer().hover((s) => s.bg(t.hover)).on_click((_e, cx) => this.setScope("commit", cx, c.sha)).tooltip(`${c.short} · ${c.author} · ${c.when}\n${c.subject}`)
        .child(div().flex_none().text_size(11).font_family(codeFont()).text_color(t.dim).child(c.short))
        .child(div().flex_1().min_w(0).text_size(12).truncate().child(c.subject))
        .child(div().flex_none().text_size(10).text_color(t.muted).child(c.when))
        .child(check(this.scope === "commit" && this.sha === c.sha)));
    return Popover.new("scope").open(this.choosingScope).on_open_change((open, cx) => { this.choosingScope = open; if (open) this.loadLog(cx); cx.notify(); })
      .trigger(box)
      .content(v_flex().mt(4).min_w(300).max_w(420).p(6).gap(2).rounded(8).border_1().border_color(t.border).bg(t.popover).shadow_md().children(options.map((o) =>
        h_flex().id(`scope-${o.scope}`).px(10).py(7).gap(10).items_center().rounded(6).when(o.ok, (e) => e.cursor_pointer().hover((s) => s.bg(t.hover)).on_click((_e, cx) => this.setScope(o.scope, cx))).when(!o.ok, (e) => e.opacity(0.5))
          .child(v_flex().flex_1().min_w(0).gap(2).child(div().text_size(12).child(o.label)).child(div().text_size(11).text_color(t.dim).truncate().child(o.detail)))
          .child(check(o.scope === this.scope))))
        .child(div().mt(4).mx(4).border_t(1).border_color(t.border))
        .child(div().px(10).pt(6).pb(2).text_size(11).text_color(t.dim).truncate().child(i.merge ? `One commit on ${i.branch}, on its own` : "One commit, on its own"))
        .child(v_flex().id("scope-commits").max_h(280).overflow_y_scrollbar().gap(1)
          .when(this.log === null, (e) => e.child(div().px(10).py(5).text_size(11).text_color(t.dim).child("Loading commits…")))
          .when(this.log !== null && !commits.length, (e) => e.child(div().px(10).py(5).text_size(11).text_color(t.dim).child("No commits")))
          .children(commits)));
  }

  // A panel under 600px has no room for a column beside the diff.
  narrow() { return (this.size?.width ?? 368) < 600; }

  // The comment box: title, the lines it is about, the textarea, Add / Cancel / Delete.
  // `docked`: a strip under the diff (narrow panel) instead of a 300px card over its top-right.
  box(t, target, docked) {
    const c = this.composer, editing = Boolean(c.editing);
    const where = c.whole ? `whole file (${this.describe(c.path)})` : target ? (target.from === target.to ? `line ${this.rows[target.from].number ?? ""}` : `lines ${this.rows[target.from].number}–${this.rows[target.to].number}`) : "those lines are no longer in the diff";
    const hint = [c.whole ? "Click a line to comment on lines instead." : editing ? "" : "Click a line to widen the range; click a highlighted line to clear it.", "Enter adds, shift-enter starts a new line, Esc cancels."].filter(Boolean).join("\n");
    // Every press inside the box stops here: the box floats over the list, and a click that
    // fell through to the row underneath would reopen the box the moment Add closed it.
    const stop = (action) => (e, cx) => { cx.stop_propagation(); action(e, cx); };
    const button = (id, label, primary, action, tip) => div().id(id).h(26).px(10).flex().items_center().rounded(6).bg(primary ? t.solid : t.raised).text_color(primary ? t.solid_foreground : t.foreground).text_size(11).font_medium().cursor_pointer().hover((s) => s.opacity(0.88)).on_click(stop(action)).tooltip(tip).child(label);
    const link = (id, label, color, action, tip) => div().id(id).h(26).px(7).flex().items_center().rounded(6).text_size(11).text_color(color).cursor_pointer().hover((s) => s.bg(t.hover)).on_click(stop(action)).tooltip(tip).child(label);
    return v_flex().id("comment-box").flex_none().gap(8).p(10).text_size(12).when(docked, (e) => e.bg(t.surface))
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation()).on_mouse_up("left", (_e, cx) => cx.stop_propagation()).on_click((_e, cx) => cx.stop_propagation())
      .when(!docked, (e) => e.absolute().top(12).right(14).w(300).rounded(10).border_1().border_color(t.border).bg(t.surface + "eb").shadow_lg())
      .when(docked, (e) => e.w_full().border_t(1).border_color(t.border))
      .child(h_flex().items_center().gap(6)
        .child(div().font_semibold().child(editing ? "Edit comment" : "Comment"))
        // The how-to lives on this "?": a tooltip on hover, and a click shows it in the box.
        .child(div().id("comment-help").size(16).flex().items_center().justify_center().rounded(8).border_1().border_color(this.help ? t.accent : t.border).text_size(10).text_color(this.help ? t.accent : t.dim).cursor_pointer().hover((s) => s.text_color(t.foreground).border_color(t.foreground)).tooltip(hint)
          .on_click(stop((_e, cx) => { this.help = !this.help; cx.notify(); })).child("?"))
        .child(div().flex_1())
        .child(div().id("comment-close").size(20).flex().items_center().justify_center().rounded(5).cursor_pointer().text_color(t.muted).hover((s) => s.bg(t.hover).text_color(t.foreground)).on_click(stop((_e, cx) => this.closeComposer(cx))).tooltip("Close (Esc)").child("×")))
      .child(div().text_size(11).text_color(t.dim).whitespace_normal().child(`${c.path.split("/").pop()} · ${where}`))
      .when(Boolean(this.help), (e) => e.child(v_flex().gap(2).px(8).py(6).rounded(6).bg(t.raised).text_size(10.5).text_color(t.dim).children(hint.split("\n").map((l) => div().whitespace_normal().child(l)))))
      .child(div().w_full().child(Textarea.new(this.note).w_full().px(8).py(6).rounded(8).border_1().border_color(t.input).bg(t.background).text_size(12).text_color(t.foreground)))
      .child(h_flex().items_center().gap(6).flex_wrap()
        .child(button("comment-add", editing ? "Save" : "Add comment", true, (_e, cx) => this.addComment(cx), "Enter"))
        .child(link("comment-cancel", "Cancel", t.dim, (_e, cx) => this.closeComposer(cx), "Esc"))
        .when(editing, (e) => e.child(div().flex_1()).child(link("comment-delete", "Delete", t.ansi1, (_e, cx) => this.deleteComment(cx), "Remove this comment from the review"))));
  }

  item(it, t, colors, target, commented) {
    const width = (this.size?.width ?? 368) - 60;
    if (it.kind === "comment") {
      const span = it.whole ? "whole file" : it.from < 0 ? "saved lines" : it.from === it.to ? `line ${this.rows[it.from].number}` : `lines ${this.rows[it.from].number}–${this.rows[it.to].number}`;
      const state = this.commentStates?.get(it.id);
      return div().w_full().h(it.height).flex_none().pl(42).pr(12).py(4).cursor_pointer()
        .child(v_flex().max_w(width).rounded(8).border_1().border_color(it.live ? t.accent : t.accent + "66").bg(t.surface).px(10).py(6).gap(3)
          .child(div().text_size(10).text_color(state ? t.ansi1 : it.live ? t.accent : t.dim).child(`Comment · ${span}${state ? ` · ${state}` : ""}${it.live ? " · editing" : " · click to edit"}`))
          .child(div().text_size(this.fontSize).whitespace_normal().text_color(it.text ? t.foreground : t.dim).child(it.text || "(empty)")));
    }
    if (it.kind === "fold") {
      return h_flex().w_full().h(this.row).flex_none().items_center().cursor_pointer().bg(t.raised + "80").text_color(t.dim).hover((s) => s.bg(t.hover).text_color(t.foreground))
        .child(div().w(this.gutter + 16).flex_none().text_center().child("⋯"))
        .child(div().flex_1().min_w(0).truncate().text_size(this.fontSize - 1).child(`${it.count} unchanged line${it.count > 1 ? "s" : ""} · click to show`));
    }
    const { kind, number, spans } = this.rows[it.i], i = it.i;
    const on = target && i >= target.from && i <= target.to, mark = commented.has(i);
    if (kind === "@") {
      return h_flex().w_full().h(this.row).flex_none().items_center().cursor_pointer().bg(t.raised).border_l(2).border_color(on ? t.accent : NONE)
        .child(div().w(this.gutter + 16).flex_none()).child(div().flex_1().min_w(0).truncate().text_color(t.dim).child(spans[0].text));
    }
    // Added and removed rows get a clear tint (stronger when targeted), a
    // colored sign column and a tinted gutter, like a GitHub diff.
    const tint = kind === "+" ? colors.added : kind === "-" ? colors.removed : null;
    return h_flex().w_full().h(this.row).flex_none().cursor_pointer().border_l(2).border_color(on ? t.accent : mark ? t.accent + "66" : NONE)
      .when(Boolean(tint), (e) => e.bg(tint + (on ? "5c" : "30")))
      .when(!tint && on, (e) => e.bg(t.selected))
      .child(div().w(this.gutter).flex_none().text_right().pr(4).when(Boolean(tint), (e) => e.bg(tint + "26")).text_color(on ? t.foreground : tint ? t.foreground + "cc" : t.dim).child(number === undefined ? "" : String(number)))
      .child(div().w(16).flex_none().text_center().font_bold().text_color(tint ?? NONE).child(kind === "+" ? "+" : kind === "-" ? "−" : " "))
      .child(h_flex().flex_1().min_w(0).whitespace_nowrap().children(spans.map((s) => s.cls ? div().text_color(colors[s.cls] ?? t.foreground).child(s.text) : div().child(s.text))));
  }

  render(cx) {
    if (props()?.turns) return div().w(1).h(1);
    if (this.dialog) return this.dialog.render(cx);
    const request = shared(OPEN);
    const turn = turnFor(shared(TURNS), focused()?.tab, this.root, this.on);
    if (this.scope === "turn" && (turn?.gen !== this.scopeInfo?.turn?.gen || turn?.to !== this.scopeInfo?.turn?.to)) cx.timer.after(1, (cx) => this.refresh(cx));
    if (request != null && this.stale(request)) cx.timer.after(1, () => setShared(OPEN, null));
    else if (key() !== this.context || (request?.id !== this.tried && this.requestedFile(request) !== null)) this.refresh(cx);
    const size = codeSize();
    if (size !== this.fontSize) { this.fontSize = size; this.row = rowOf(size); this.measure(); }
    // "Full file" may have been switched in another copy of the panel.
    else if (this.full() !== this.builtFull) this.rebuild();
    const cleared = shared("reviewer.cleared");
    if (cleared?.id !== this.cleared && cleared?.drafts?.some((d) => d.key === this.draftKey())) {
      this.cleared = cleared.id;
      this.comments = shared(DRAFTS)?.[this.draftKey()] ?? [];
      this.rebuild();
    }
    const t = theme(), colors = palette(props()?.palette, t), add = this.files.reduce((n, f) => n + f.add, 0), del = this.files.reduce((n, f) => n + f.del, 0);
    const target = this.target(), n = this.comments.length, canAsk = Boolean(this.open && this.rows.length);
    const earlierCount = this.scope === "turn" ? Object.entries(shared(DRAFTS) ?? {})
      .filter(([k]) => k !== this.draftKey() && (k.startsWith(`${this.on ?? ""}:${this.root}:turn:`) || k === `${this.on ?? ""}:${this.root}:turn`))
      .reduce((sum, [, list]) => sum + list.length, 0) : 0;
    const commented = new Set();
    for (const it of this.items) if (it.kind === "comment") for (let j = it.from; j <= it.to; j++) commented.add(j);
    const perFile = {};
    for (const c of this.comments) perFile[c.path] = (perFile[c.path] ?? 0) + 1;
    const button = (id, label, primary, action) => div().id(id).h(24).px(10).flex().items_center().rounded(6).bg(primary ? t.solid : t.raised).text_color(primary ? t.solid_foreground : t.foreground).text_size(12).font_medium().cursor_pointer().hover((s) => s.opacity(0.88)).on_click(action).child(label);
    const link = (id, label, action) => div().id(id).h(24).px(8).flex().items_center().rounded(6).text_size(12).text_color(t.dim).cursor_pointer().hover((s) => s.bg(t.hover).text_color(t.foreground)).on_click(action).child(label);
    return v_flex().id("changes").size_full().min_h(0).relative().rounded(10).overflow_hidden().bg(t.background).border_1().border_color(t.border).text_color(t.foreground).text_size(13).track_focus(this.handle)
      .on_size_change((size, cx) => { const w = this.size?.width; this.size = size; if (w !== size.width) { this.rebuild(); cx.notify(); } })
      .on_key_down((e, cx) => {
        if (e.key === "escape" && this.composer) { this.closeComposer(cx); cx.stop_propagation(); }
        else if (e.key === "enter" && (e.modifiers?.platform || e.modifiers?.control) && this.composer) { this.addComment(cx); cx.stop_propagation(); }
      })
      .child(h_flex().h(42).flex_none().px(14).gap(8).items_center().border_b(1).border_color(t.border)
        .child(div().font_semibold().child("Changes"))
        .child(div().h(24).px(8).flex().items_center().rounded(6).border_1().border_color(t.border).text_size(12).text_color(t.muted).child(`${this.files.length} files`))
        .when(Boolean(this.root) && this.hasHead, (e) => e.child(this.scopePicker(t)))
        .child(div().flex_1())
        // Full file: the icon shows what a click does (unfold when folded, fold when the whole file shows).
        .when(this.gaps?.length > 0, (e) => e.child(div().id("full-file").size(24).flex().items_center().justify_center().rounded(6).border_1().border_color(this.full() ? t.accent : t.border).bg(this.full() ? t.accent + "22" : NONE).text_color(this.full() ? t.accent : t.dim).cursor_pointer().hover((s) => s.bg(t.hover).text_color(t.foreground))
          .tooltip(this.full() ? "Fold the unchanged lines" : "Show the whole file").on_click((_e, cx) => this.toggleFull(cx))
          .child(svg(this.full() ? "mods/reviewer/fold-vertical.svg" : "mods/reviewer/unfold-vertical.svg").size(13))))
        .child(div().text_size(11).text_color(t.ansi2).child(`+${add}`)).child(div().text_size(11).text_color(t.ansi1).child(`−${del}`))
        .when(n > 0 || earlierCount > 0, (e) => e.when(n > 0, (e) => e.child(link("review-discard", "Discard", (_e, cx) => this.setComments([], cx)))).child(button("review-submit", `Submit review · ${n + earlierCount}`, true, (_e, cx) => this.submit(cx))))
        .when(n === 0 && earlierCount === 0 && canAsk, (e) => e.child(button("ask", "Ask about diff", false, (_e, cx) => this.askAbout(null, cx)))))
      .child(v_flex().id("changes-list").flex_none().h(Math.min(200, Math.max(44, this.files.length * 28 + 12))).overflow_y_scrollbar().p(6).border_b(1).border_color(t.border).children(this.files.map((f) => {
        const parts = f.path.split("/"), name = parts.pop(), k = perFile[f.path];
        return h_flex().id(`change-${f.path}`).h(28).flex_none().px(8).gap(8).items_center().rounded(7).cursor_pointer().when(this.open === f.path, (e) => e.bg(t.selected)).hover((s) => s.bg(t.hover)).on_click((_e, cx) => this.pick(f.path, cx))
          .child(div().w(14).text_size(11).text_color(f.status === "A" ? t.ansi2 : f.status === "D" ? t.ansi1 : f.status === "U" ? t.ansi1 : t.blocked).child(f.status))
          .child(h_flex().flex_1().min_w(0).child(div().text_color(t.dim).truncate().child(parts.length ? parts.join("/") + "/" : "")).child(div().max_w(260).min_w(0).truncate().child(f.noLongerChanged ? `${name} · No longer changed, with comments` : name)))
          // One speech bubble: the draft count when there are drafts, and a click comments on the whole file.
          .child(h_flex().id(`comment-file-${f.path}`).h(18).min_w(18).px(k ? 5 : 0).gap(3).items_center().justify_center().rounded(4).cursor_pointer()
            .when(Boolean(k), (e) => e.bg(t.accent + "33").text_size(10).text_color(t.foreground))
            .when(!k, (e) => e.text_color(t.muted))
            .hover((s) => s.bg(k ? t.accent + "55" : t.hover).text_color(t.foreground))
            .tooltip(k ? `${k} draft comment${k > 1 ? "s" : ""} · click to comment on the whole file` : "Comment on the whole file")
            .on_click((_e, cx) => { cx.stop_propagation(); this.commentFile(f.path, cx); })
            .when(Boolean(k), (e) => e.child(String(k))).child(svg("mods/reviewer/comment.svg").size(k ? 10 : 12)))
          .when(f.add > 0, (e) => e.child(div().text_size(11).text_color(t.ansi2).child(`+${f.add}`))).when(f.del > 0, (e) => e.child(div().text_size(11).text_color(t.ansi1).child(`−${f.del}`)));
      })).when(!this.files.length, (e) => e.child(div().p(8).text_color(t.dim).child(this.error || (this.loading ? "Loading changes…" : !this.root ? "No folder" : this.scope === "work" ? "No uncommitted changes" : this.scope === "turn" && !this.scopeInfo?.turn?.gen ? "no agent turn seen since the window opened" : "No changes in this scope")))))
      .when(this.limited, el => el.child(div().px(12).py(4).text_size(11).text_color(t.dim).child("Showing the first 1,000 changed files")))
      .child(h_flex().flex_1().min_h(0).items_stretch()
        .child(div().flex_1().min_w(0).min_h(0).relative().font_family(codeFont()).text_size(this.fontSize)
        .child(div().id("changes-diff-x").size_full().overflow_x_scrollbar()
          .child(div().w_full().min_w(this.diffWidth).h_full().child(v_virtual_list("changes-diff", this.items.length, this.sizes.length ? this.sizes : this.row, (i) => this.items[i].key,
            (range) => this.items.slice(range.start, range.end).map((it) => this.item(it, t, colors, target, commented))).size_full().track_scroll(this.scroll)
            .on_item_click((k, cx) => { if (k.startsWith("f:")) this.unfold(Number(k.slice(2)), cx); else if (k.startsWith("c:")) { if (k.slice(2) !== this.composer?.editing) this.editComment(k.slice(2), cx); } else this.clickRow(Number(k.slice(2)), cx); })
            .on_item_secondary_click((k, _e, cx) => { if (!k.startsWith("r:")) return; const i = Number(k.slice(2)); const r = this.rows[i]; if (!r || r.kind === "") return; this.askAbout(r.kind === "@" ? this.rows.map((_r, j) => j).filter((j) => this.rows[j].hunk === i && this.rows[j].kind !== "") : [i], cx); }))))
        .child(Scrollbar.vertical("changes-diff").viewport_from_layout().absolute().inset_0())
        .when(!this.open && this.files.length > 0, (e) => e.child(div().absolute().top(6).px(12).text_color(t.dim).child("Select a file to view its changes")))
        .when(canAsk && !this.composer && n === 0, (e) => e.child(div().absolute().bottom(6).right(14).px(8).py(3).rounded(6).bg(t.raised + "e0").text_size(10).text_color(t.dim).child("Click a line to comment · right-click to ask"))))
        // The comment box, a card floating over the top-right of the diff while it is open (a strip below it on a narrow panel).
        .when(Boolean(this.composer) && !this.narrow(), (e) => e.child(this.box(t, target, false))))
      // Narrow panel: the comment box is a strip under the diff instead of a column beside it.
      .when(Boolean(this.composer) && this.narrow(), (e) => e.child(this.box(t, target, true)))
      .when(Boolean(this.note_), (e) => e.child(div().px(10).pb(8).text_size(11).text_color(t.ansi1).child(this.note_)));
  }

  pick(path, cx) {
    this.open = this.open === path ? null : path; this.setLines([]); this.note_ = null;
    this.closed = !this.open;
    const context = this.context;
    if (this.open) cx.spawn(async (cx) => {
      try { await this.load(path, context); }
      catch (e) { if (key() === context && this.open === path) this.note_ = `Cannot preview this diff (too large or unreadable): ${e}`; }
      cx.notify();
    });
    cx.notify();
  }
}
