// Vendored from jmayaalv/herdr-app-resize @4a3b91b11a4c950b1afae87c14ab2fd6236c013b (MIT).
// Moves the divider beside a pane in Herdr's layout document (each tab's root is a tree
// of row/column/block nodes; a node's share of its split is size.weight, default 1).
// The divider moves the way the arrow points: the pane's right (bottom) edge when it has
// one, else its left (top) edge, like tmux.

const AXIS = { left: "row", right: "row", up: "column", down: "column" };
const SIGN = { left: -1, right: 1, up: -1, down: 1 };
const MIN = 0.1; // no pane gets smaller than 10% of its split

function pathTo(node, id, path = []) {
  if (node.id === id) return path;
  for (const [i, child] of (node.children ?? []).entries()) {
    const found = pathTo(child, id, [...path, [node, i]]);
    if (found) return found;
  }
  return null;
}

// Changes the tree in place; false when there is no divider to move that way.
export function resize(root, paneId, dir, steps = 1, step = 0.05) {
  const path = pathTo(root, paneId);
  if (!path) return false;
  const splits = path.filter(([n]) => n.type === AXIS[dir] && n.children.length > 1).reverse();
  const after = splits.find(([n, i]) => i < n.children.length - 1);
  const target = after ?? splits.find(([, i]) => i > 0);
  if (!target) return false;
  const [split, i] = target;
  const d = after ? i : i - 1; // the divider sits between children d and d + 1
  const kids = split.children;
  if (kids.some((c) => c.size && c.size.weight == null)) return false; // px sizes: not ours
  const w = kids.map((c) => c.size?.weight ?? 1);
  const total = w.reduce((a, b) => a + b, 0);
  const pair = w[d] + w[d + 1];
  const lo = MIN * total;
  const hi = pair - MIN * total;
  if (lo > hi) return false;
  const a = Math.min(hi, Math.max(lo, w[d] + SIGN[dir] * steps * step * total));
  if (Math.abs(a - w[d]) < 1e-9) return false;
  kids[d].size = { weight: a };
  kids[d + 1].size = { weight: pair - a };
  return true;
}

// The whole document: finds the tab holding the pane.
export function resizeDoc(doc, paneId, dir, steps) {
  return (doc?.spaces ?? []).some((s) => s.tabs.some((t) => resize(t.root, paneId, dir, steps)));
}
