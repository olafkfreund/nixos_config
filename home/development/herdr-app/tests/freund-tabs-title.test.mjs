import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const state = { calls: [], execResult: null, spaces: [] };
globalThis.freundTabsTest = state;
globalThis.localStorage = { getItem: () => null };

const stub = source => `data:text/javascript,${encodeURIComponent(source)}`;
const imports = {
  "gpui-kit": stub("export class View {} export const div = () => {}; export const svg = () => {}; export const image = () => {};"),
  "gpui-base": stub("export const h_flex = () => {}; export const ScrollHandle = { new: () => ({}) };"),
  herdr: stub(`
    const state = globalThis.freundTabsTest;
    export const spaces = () => state.spaces;
    export const setWindowTitle = title => state.calls.push(title);
    export const exec = () => state.execResult;
    export const panes = () => [];
    export const run = () => {};
    export const openOverlay = () => {};
    export const theme = () => {};
    export const window = () => {};
    export const shared = () => {};
    export const layout = () => {};
    export const settings = () => {};
  `),
};

let source = await readFile(new URL("../mods/freund-tabs/main.js", import.meta.url), "utf8");
for (const [name, url] of Object.entries(imports)) {
  const specifier = `from "${name}"`;
  assert.equal(source.split(specifier).length, 2, `${name} import occurs once`);
  source = source.replace(specifier, `from "${url}"`);
}
const dir = await mkdtemp(join(tmpdir(), "freund-tabs-title-"));
let Tabs;
try {
  const file = join(dir, "main.mjs");
  await writeFile(file, source);
  ({ default: Tabs } = await import(pathToFileURL(file).href));
} finally {
  await rm(dir, { recursive: true, force: true });
}

function tabs(execResult) {
  state.calls = [];
  state.execResult = execResult;
  const view = Object.create(Tabs.prototype);
  view.init();
  return view;
}

const settled = () => new Promise(resolve => setImmediate(resolve));

// T1: a hostname result arriving during cleanup cannot restore the old title.
let resolveHost;
let view = tabs(new Promise(resolve => { resolveHost = resolve; }));
view.activeSpace = { name: "Work", machine: null };
view.retitle();
await view.close();
assert.deepEqual(state.calls, ["Work", null]);
resolveHost({ stdout: "p620\n" });
await settled();
assert.deepEqual(state.calls, ["Work", null]);
assert.equal(view.host, null);
console.log("T1 late hostname after close");

// T2: configured machine takes precedence; failed lookup leaves the bare name.
view = tabs(Promise.resolve({ stdout: "p620\n" }));
await settled();
view.activeSpace = { name: "Work", machine: null };
view.retitle();
view.activeSpace = { name: "Remote", machine: "razer" };
view.retitle();
assert.deepEqual(state.calls, [null, "p620: Work", "razer: Remote"]);
view = tabs(Promise.reject(new Error("hostname failed")));
await settled();
view.activeSpace = { name: "Work", machine: null };
view.retitle();
assert.deepEqual(state.calls, ["Work"]);
console.log("T2 local, remote and unknown host");

// T3: unchanged data is silent; each name or machine change emits once.
view = tabs(Promise.resolve({ stdout: "p620\n" }));
await settled();
view.activeSpace = { name: "Work", machine: null };
view.retitle();
view.retitle();
view.activeSpace.name = "Renamed";
view.retitle();
view.activeSpace.machine = "razer";
view.retitle();
assert.deepEqual(state.calls, [null, "p620: Work", "p620: Renamed", "razer: Renamed"]);
console.log("T3 title de-duplication and changes");

// T4: no active space clears the title once, including on the first render.
view = tabs(Promise.reject(new Error("hostname failed")));
await settled();
view.retitle();
view.retitle();
assert.deepEqual(state.calls, [null]);
console.log("T4 no active space");

// T5: closing always resets the window title once.
view = tabs(Promise.reject(new Error("hostname failed")));
await settled();
await view.close();
assert.deepEqual(state.calls, [null]);
console.log("T5 close resets title");
