// Compare every saved line, including the interior of a range.
export function commentState(comment, rows, quote) {
  if (comment.whole) return null;
  if (!rows || !comment.quote || !comment.from) return "lines changed";
  const lines = comment.quote.split("\n").length;
  return rows.some((row, i) => row.kind === comment.from.kind && row.number === comment.from.number
    && row.text === comment.from.text && quote(rows.slice(i, i + lines)) === comment.quote) ? null : "lines changed";
}
