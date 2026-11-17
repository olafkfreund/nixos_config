// The send dialog of reviewer, opened as an overlay of the same mod:
//   openOverlay({ mod: "reviewer", kind: "dialog", width, height, props: { dialog: true, title, context, sent } })
// (main.js hands the copy over to this class when props().dialog is set).
// `context` is text the caller already formatted (a file, lines, a hunk);
// `title` is the short label at the top; `sent` (optional) is a shared key
// the dialog sets to the send time once the text went out, so the caller
// can react (the panel clears its comments).
// Sending is a stub until plan step 6 (paste into an agent of the tab); no
// agent is started and nothing is typed into a terminal. The context is
// read-only: it scrolls both ways and can be copied.
// Esc closes. Commands: "reviewer.send", "reviewer.close".
import { div, svg } from "gpui-kit";
import { v_flex, h_flex, TextareaState, Textarea, Popover } from "gpui-base";
import { agents, focused, props, closeOverlay, theme, settings, nextCommand } from "herdr";

const DOT = { working: "working", blocked: "blocked", done: "done", idle: "idle" };

export class Dialog {
  init(_props, cx) {
    const p = props() ?? {};
    this.context = String(p.context ?? ""); this.title = p.title ?? "";
    this.note = ""; this.pick = null; this.error = null; this.sending = false; this.closed = false; this.confirm = false; this.choosing = false; this.copied = false;
    this.input = TextareaState.new({ placeholder: this.context ? "Your note to the agent (optional)…" : "What do you want to ask?", rows: this.context ? 2 : 3 });
    this.input.set_auto_grow(this.context ? 2 : 3, this.context ? 4 : 6);
    this.input.on("change", (_e, cx) => { this.note = this.input.value(); this.error = null; this.confirm = false; cx.notify(); });
    this.input.on("submit", (_e, cx) => this.send(cx));
    this.input.focus();
    cx.timer.after(600, () => this.input.focus());
    this.handle = cx.focus_handle();
    cx.spawn(async (cx) => {
      for (;;) {
        const c = await nextCommand();
        if (c === "send") this.send(cx);
        else if (c === "close") this.close();
        cx.notify();
      }
    });
  }

  close() { this.closed = true; closeOverlay(props().overlay); }
  // The agents in the focused tab; the picked one, else the focused, else an idle one, else the first.
  candidates() {
    const tab = focused()?.tab;
    return agents().filter((a) => a.tab === tab);
  }
  target() {
    const list = this.candidates();
    return list.find((a) => a.address === this.pick) ?? list.find((a) => a.focused) ?? list.find((a) => a.status === "idle") ?? list[0] ?? null;
  }
  text() { return [this.note.trim(), this.context.trim()].filter(Boolean).join("\n\n"); }

  // Stub (plan step 6): builds the text and does nothing else.
  send(cx) {
    if (this.sending) return;
    if (!this.text()) { this.error = "Type a note first"; cx.notify(); return; }
    this.error = "Sending is not wired yet"; cx.notify();
  }

  render(cx) {
    const t = theme(), list = this.candidates(), agent = this.target(), isTarget = (a) => Boolean(agent) && a.address === agent.address;
    const name = (a) => `${a.program?.name ?? a.app ?? a.address}`;
    const button = (id, text, primary, action, disabled) => h_flex().id(id).h(32).px(14).items_center().rounded(8).border_1()
      .border_color(primary ? t.solid : t.input).bg(primary ? t.solid : t.raised).text_color(primary ? t.solid_foreground : t.foreground).text_size(12.5).font_medium()
      .when(disabled, (e) => e.opacity(0.5)).when(!disabled, (e) => e.cursor_pointer().hover((s) => s.opacity(0.88)).on_click(action)).child(text);
    const contextLines = this.context.split("\n"), shown = contextLines.slice(0, 600);
    const contextWidth = Math.max(...shown.map((l) => l.length)) * 6.7 + 24;
    const link = (id, text, action, icon) => h_flex().id(id).h(20).px(5).gap(4).items_center().rounded(4).text_size(11).text_color(t.dim).cursor_pointer().hover((s) => s.text_color(t.foreground).bg(t.hover)).on_click(action)
      .when(Boolean(icon), (e) => e.child(svg(`mods/reviewer/${icon}.svg`).size(12))).child(text);
    const dot = (a) => div().size(7).rounded(4).bg(t[DOT[a.status]] ?? t.unknown);
    // The target as a select-looking box; with a chevron when there is a list to open.
    const agentBox = (a, opens) => h_flex().id("to-box").h(28).px(9).gap(7).items_center().rounded(7).border_1().border_color(this.choosing ? t.accent : t.input).bg(t.raised)
      .when(opens, (e) => e.cursor_pointer().hover((s) => s.bg(t.hover)))
      .child(dot(a)).child(div().text_size(12).child(`${name(a)} · ${a.tab_name}`)).child(div().text_size(10.5).text_color(t.dim).child(a.status))
      .when(opens, (e) => e.child(svg("mods/reviewer/chevron-down.svg").size(12).text_color(t.dim)));
    return v_flex().id("ask-agent").track_focus(this.handle)
      .on_key_down((e, cx) => {
        if (e.key === "escape") { this.close(); cx.stop_propagation(); }
        else if (e.key === "enter" && (e.modifiers?.platform || e.modifiers?.control)) { this.send(cx); cx.stop_propagation(); }
      })
      .size_full().min_h(0).p(18).gap(10).bg(t.popover).text_color(t.foreground).text_size(13)
      .child(h_flex().items_center().gap(8)
        .child(div().text_size(15).font_semibold().child("Ask the agent"))
        .child(div().flex_1().min_w(0).truncate().text_size(12).text_color(t.dim).child(this.title))
        .child(div().text_size(11).text_color(t.dim).child("Esc")))
      // Who gets it: a dropdown showing the focused agent; open it to pick another in the space.
      .child(!list.length
        ? div().text_size(12).text_color(t.muted).child("No agent in this tab.")
        : h_flex().gap(8).items_center()
            .child(div().text_size(11.5).text_color(t.dim).child("To"))
            .child(list.length > 1
              ? Popover.new("to").open(this.choosing).on_open_change((open, cx) => { this.choosing = open; cx.notify(); })
                  .trigger(agentBox(agent, true))
                  .content(v_flex().mt(4).min_w(260).p(4).rounded(8).border_1().border_color(t.border).bg(t.popover).shadow_md().children(list.map((a) =>
                    h_flex().id(`to-${a.address}`).h(28).px(8).gap(7).items_center().rounded(6).cursor_pointer().hover((s) => s.bg(t.hover))
                      .on_click((_e, cx) => { this.pick = a.address; this.confirm = false; this.choosing = false; cx.notify(); })
                      .child(dot(a))
                      .child(div().flex_1().text_size(12).child(`${name(a)} · ${a.tab_name}`))
                      .child(div().text_size(10.5).text_color(t.dim).child(a.status))
                      .child(isTarget(a) ? svg("mods/reviewer/check.svg").size(12).text_color(t.accent) : div().w(12)))))
              : agentBox(agent, false)))
      .child(Textarea.new(this.input).w_full().px(10).py(8).rounded(9).border_1().border_color(t.input).bg(t.background).text_size(12.8).text_color(t.foreground))
      // The context, read-only: what the caller built (a review, a hunk). Scrolls both ways.
      .when(Boolean(this.context), (el) => el.child(v_flex().flex_1().min_h(100).gap(4)
        .child(h_flex().items_center().gap(6)
          .child(div().text_size(11).text_color(t.dim).child(`Sent after your note · ${contextLines.length} lines · read-only`))
          .child(div().flex_1())
          .child(link("context-copy", this.copied ? "Copied" : "Copy", (_e, cx) => { try { cx.write_to_clipboard(this.context); this.copied = true; } catch (e) { this.error = `Copy failed: ${e}`; } cx.notify(); }, this.copied ? "check" : "copy")))
        .child(div().id("ask-context-x").flex_1().min_h(0).rounded(8).border_1().border_color(t.border).bg(t.background).overflow_x_scrollbar()
          .child(v_flex().id("ask-context").h_full().min_w(contextWidth).overflow_y_scrollbar().p(8)
            .font_family(settings().font_family ?? "JetBrains Mono").text_size(11).text_color(t.muted).whitespace_nowrap()
            .children(shown.map((l) => div().h(16).flex_none().child(l || " ")))
            .when(contextLines.length > shown.length, (el) => el.child(div().text_color(t.dim).child(`… ${contextLines.length - shown.length} more lines are sent too`)))))))
      // A long paste can be slow, or cut short by some agents: say so above 8 KB.
      .when(this.context.length > 8000, (el) => el.child(div().text_size(11).text_color(t.blocked).whitespace_normal().child(`This is ${(this.context.length / 1024).toFixed(0)} KB of text pasted into the agent's terminal; some agents are slow or cut it short at this size. Consider sending fewer comments at a time.`)))
      .when(Boolean(this.error), (el) => el.child(div().text_size(11.5).text_color(t.ansi1).child(this.error)))
      .child(h_flex().items_center().gap(8)
        .child(div().flex_1().min_w(0).truncate().text_size(11.5).text_color(this.confirm ? t.blocked : t.dim)
          .child(agent ? `goes to ${name(agent)} as one message` : "No agent in this tab"))
        .child(button("ask-cancel", "Cancel", false, () => this.close()))
        .child(button("ask-send", this.sending ? "Sending…" : "Send", true, (_e, cx) => this.send(cx), this.sending)));
  }
}
