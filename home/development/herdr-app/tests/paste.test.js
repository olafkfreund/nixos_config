import { test } from "node:test";
import assert from "node:assert/strict";
import { confirmed } from "../mods/reviewer/paste.js";

test("a new paste placeholder confirms the paste", () => {
  assert.equal(confirmed("prompt", "prompt\n[Pasted text #1 +3 lines]", "review\nlast line"), true);
  assert.equal(confirmed("[Pasted text #1 +3 lines]", "[Pasted text #2 +3 lines]", "review\nlast line"), true);
  assert.equal(confirmed("[Pasted text #1 +3 lines]", "[Pasted text #1 +3 lines]\n[Pasted text #1 +3 lines]", "review\nlast line"), true);
});

test("an added tail confirms the paste", () => {
  assert.equal(confirmed("prompt", "prompt\nlast line", "review\nlast line\n"), true);
  assert.equal(confirmed("prompt", `prompt\n${"x".repeat(60)}`, `review\n${"x".repeat(60)}more`), true);
});

test("unchanged or unrelated screens do not confirm", () => {
  assert.equal(confirmed("prompt", "prompt", "review\nlast line"), false);
  assert.equal(confirmed("prompt", "prompt\nunrelated output", "review\nlast line"), false);
  assert.equal(confirmed("prompt", "prompt\nlast li\nne", "review\nlast line"), false);
  assert.equal(confirmed("[Pasted text #1 +3 lines]", "[Pasted text #1 +3 lines]\nunrelated output", "review\nlast line"), false);
  assert.equal(confirmed("prompt\nlast line", "prompt\nlast line\nunrelated output", "review\nlast line"), false);
});
