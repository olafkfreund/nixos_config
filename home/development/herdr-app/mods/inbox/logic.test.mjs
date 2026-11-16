import test from "node:test";
import assert from "node:assert/strict";
import { capLine, fetchInbox, merge, parseItems, queries } from "./logic.js";

const gh = { provider: "GitHub", kind: "issue", reason: "assignee" };
const gl = { provider: "GitLab", kind: "issue", reason: "assignee" };
const ghItem = { repository: { nameWithOwner: "group/repo" }, number: 7, title: "Fix", url: "https://github.com/group/repo/issues/7", updatedAt: "2026-11-16T00:00:00Z" };
const glItem = { references: { full: "group/repo#7" }, iid: 7, title: "Fix", web_url: "https://gitlab.com/group/repo/-/issues/7", updated_at: "2026-11-16T00:00:00Z" };

test("merges every matching reason by item ID", () => {
  const item = parseItems(gh, JSON.stringify([ghItem]))[0];
  const result = merge([{ query: gh, items: [item] }, { query: { ...gh, reason: "author" }, items: [{ ...item, reasons: ["author"] }] }]);
  assert.equal(result.rows.length, 1);
  assert.deepEqual(result.rows[0].reasons, ["assignee", "author"]);
});

test("keeps GitHub and GitLab IDs separate", () => {
  assert.equal(capLine(true), "showing 100 of more, open on the web");
  assert.equal(capLine(false), "");
  const result = merge([{ query: gh, items: parseItems(gh, JSON.stringify([ghItem])), capped: true }, { query: gl, items: parseItems(gl, JSON.stringify([glItem])) }]);
  assert.deepEqual(result.rows.map(row => row.id).sort(), ["gh:group/repo#7", "gl:group/repo#7"]);
  assert.deepEqual(result.capped, ["GitHub"]);
});

test("a full query displays the cap line", async () => {
  const items = Array.from({ length: 100 }, (_, i) => ({ ...ghItem, number: i + 1 }));
  const result = await fetchInbox(async (cmd, args) => cmd === "glab"
    ? { code: 1, stderr: "not logged in" }
    : { code: 0, stdout: JSON.stringify(args.includes("--assignee=@me") && args[1] === "issues" ? items : []), stderr: "" });
  assert.equal(result.rows.length, 100);
  assert.equal(capLine(result.capped.includes("GitHub")), "showing 100 of more, open on the web");
});

test("one provider failing leaves the other provider's rows", async () => {
  const calls = [];
  const result = await fetchInbox(async (cmd, args) => {
    calls.push([cmd, args]);
    if (cmd === "glab") return { code: 1, stdout: "", stderr: "not logged in" };
    return { code: 0, stdout: JSON.stringify(args[1] === "issues" ? [ghItem] : []), stderr: "" };
  });
  assert.equal(result.errors.GitLab, "Error: not logged in");
  assert.equal(result.rows.length, 1);
  assert.deepEqual(result.rows[0].reasons, ["assignee", "author"]);
  assert.equal(calls.filter(([cmd]) => cmd === "glab").length, 1);
  assert.equal(queries("me").length, 10);
});
