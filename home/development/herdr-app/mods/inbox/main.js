import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { checking, exec, home, notify, panes, run, spaces, theme } from "herdr";
import { fetchInbox, capLine } from "./logic.js";

const ROOTS = ["~/.config", "/mnt/code"];

function sameRepo(remote, item) {
  const host = item.provider === "GitHub" ? "github.com" : "gitlab.com";
  const match = remote.match(/(?:https?:\/\/|ssh:\/\/git@|git@)([^/:]+)[:/]([^\s]+?)(?:\.git)?(?:\s|$)/);
  return Boolean(match && match[1] === host && match[2].replace(/\.git$/, "") === item.repo);
}

async function hasRemote(folder, item) {
  const r = await exec("git", ["-C", folder, "remote", "-v"]);
  return r.code === 0 && r.stdout.split("\n").some(line => sameRepo(line, item));
}

async function cloneFolder(item) {
  for (const space of spaces().filter(s => !s.machine)) {
    for (const pane of panes().filter(p => p.cwd && space.tabs.some(t => t.id === p.tab))) {
      if (await hasRemote(pane.cwd, item)) return pane.cwd;
    }
  }
  for (const root of ROOTS.map(r => r.startsWith("~/") ? home() + r.slice(1) : r)) {
    const found = await exec("find", [root, "-maxdepth", "3", "-name", ".git", "-prune", "-print"]).catch(() => null);
    if (found?.code !== 0) continue;
    for (const git of found.stdout.split("\n").filter(Boolean)) {
      const folder = git.slice(0, -5);
      if (await hasRemote(folder, item)) return folder;
    }
  }
  return null;
}

export default class Inbox extends View {
  init(_props, cx) {
    this.rows = []; this.errors = {}; this.capped = []; this.loading = false;
    if (!checking()) {
      this.refresh(cx);
      cx.timer.every(300000, cx => this.refresh(cx));
    }
  }

  refresh(cx) {
    if (this.loading) return;
    this.loading = true; cx.notify();
    cx.spawn(async cx => {
      try { Object.assign(this, await fetchInbox(exec)); }
      catch (e) { this.errors = { Inbox: String(e) }; }
      finally { this.loading = false; cx.notify(); }
    });
  }

  open(item, cx) {
    cx.spawn(async cx => {
      try {
        const r = await exec("xdg-open", [item.url]);
        if (r.code !== 0) throw new Error(r.stderr || "xdg-open failed");
      } catch (e) { notify({ title: "Cannot open item", body: String(e), level: "error" }); }
      cx.notify();
    });
  }

  start(item, cx) {
    cx.spawn(async cx => {
      try {
        const folder = await cloneFolder(item);
        if (!folder) notify({ title: "No local clone", body: item.repo, level: "warning" });
        else run("space.new", { folder, argv: ["claude"], task: `Work on ${item.url}` });
      } catch (e) { notify({ title: "Cannot start agent", body: String(e), level: "error" }); }
      cx.notify();
    });
  }

  render(cx) {
    const t = theme();
    return v_flex().id("inbox").size_full().min_h(0).bg(t.background).text_color(t.foreground).text_size(13)
      .child(h_flex().h(44).flex_none().px(14).gap(12).items_center().border_b(1).border_color(t.border)
        .child(div().font_semibold().child("Issues inbox"))
        .child(div().flex_1())
        .child(div().id("inbox-refresh").cursor_pointer().text_color(t.accent).on_click((_e, cx) => this.refresh(cx)).child(this.loading ? "Refreshing…" : "Refresh")))
      .child(v_flex().id("inbox-list").flex_1().min_h(0).overflow_y_scrollbar().p(10).gap(5)
        .children(Object.entries(this.errors).map(([provider, error]) => div().p(8).text_color(t.ansi1).child(`${provider}: ${error}`)))
        .when(!this.rows.length, el => el.child(div().p(8).text_color(t.muted).child(this.loading ? "Loading…" : "No open items")))
        .children(this.rows.map(item => v_flex().id(`inbox-${item.id}`).p(9).gap(5).rounded(7).bg(t.raised)
          .child(div().truncate().font_semibold().child(`${item.repo}${item.kind === "mr" ? "!" : "#"}${item.number}  ${item.title}`))
          .child(h_flex().gap(12).items_center()
            .child(div().flex_1().truncate().text_size(11).text_color(t.muted).child(`${item.provider} · ${item.reasons.join(", ")}`))
            .child(div().id(`open-${item.id}`).cursor_pointer().text_color(t.accent).on_click((_e, cx) => this.open(item, cx)).child("Open"))
            .child(div().id(`start-${item.id}`).cursor_pointer().text_color(t.accent).on_click((_e, cx) => this.start(item, cx)).child("Start agent")))))
        .children(this.capped.map(provider => div().p(8).text_color(t.muted).child(`${provider}: ${capLine(true)}`))));
  }
}
