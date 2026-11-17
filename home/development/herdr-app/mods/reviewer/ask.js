// Opens the send dialog (dialog.js, an overlay of this mod: the person adds a
// note and picks the agent). Nothing is sent from here.
import { openOverlay } from "herdr";

/** `title`: a short label (the file and lines). `context`: the text the agent gets, already formatted.
 *  `sent`: a shared key the dialog sets to the send time once the text went out.
 *  Resolves "dialog" (opened) or "none" (the overlay could not open). */
export async function ask({ title, context, sent }) {
  try { openOverlay({ mod: "reviewer", kind: "dialog", width: context ? 680 : 560, height: context ? 560 : 250, props: { dialog: true, title, context, sent } }); return "dialog"; }
  catch (e) { console.log(`the send dialog could not open: ${e}`); return "none"; }
}
