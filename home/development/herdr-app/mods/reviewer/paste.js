const placeholders = (screen) => [...screen.matchAll(/\[Pasted text #(\d+) \+\d+ lines\]/g)].map((match) => match[1]);

export function confirmed(before, after, text) {
  const old = placeholders(before);
  const current = placeholders(after);
  if (current.length > old.length || current.some((id) => !old.includes(id))) return true;

  const tail = text.split("\n").findLast((line) => line.trim())?.slice(0, 60);
  return !!tail && after.split(tail).length > before.split(tail).length;
}
