import { test } from "node:test";
import assert from "node:assert/strict";
import { commentState } from "../mods/reviewer/stale.js";

const rows = ["first", "middle", "last"].map((text, i) => ({ kind: "+", number: i + 1, text }));
const quote = (lines) => lines.map((r) => `${String(r.number).padStart(5)} ${r.kind} ${r.text}`).join("\n");
const comment = { from: rows[0], to: rows[2], quote: quote(rows), text: "Check this range" };

test("whole saved quote detects an interior edit without changing its anchors", () => {
  assert.equal(commentState(comment, rows, quote), null);
  assert.equal(commentState(comment, [rows[0], { ...rows[1], text: "edited" }, rows[2]], quote), "lines changed");
  assert.equal(commentState(comment, null, quote), "lines changed");
  assert.equal(comment.quote, quote(rows));
});

test("the anchor must match at its original line number", () => {
  assert.equal(commentState(comment, rows.map((r) => ({ ...r, number: r.number + 1 })), quote), "lines changed");
  assert.equal(commentState({ whole: true }, null, quote), null);
});
