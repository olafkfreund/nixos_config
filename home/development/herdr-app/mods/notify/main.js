// Toast mod: hands notifications to the desktop (notify-send). "Open" runs the
// toast's action, as the shipped toast does on click (usually agent.focus).
import { View, div } from "gpui-kit";
import { props, exec, closeOverlay } from "herdr";

const SCRIPT = `r=$(notify-send -a Herdr -A open=Open -- "$1" "$2")
[ "$r" = open ] && [ -n "$3" ] && herdr-app do "$3" "$4"`;

export default class Notify extends View {
  render() {
    const p = props() ?? {};
    if (!this.sent) {
      this.sent = true;
      const action = p.action?.name ?? "";
      const args = JSON.stringify(p.action?.args ?? {});
      exec("sh", ["-c", SCRIPT, "notify", p.title ?? "", p.body ?? "", action, args]);
      if (p.overlay) closeOverlay(p.overlay); // check runs without an overlay
    }
    return div();
  }
}
