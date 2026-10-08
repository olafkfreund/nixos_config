import type { BusLine } from '../types'

// Take the first array found at the top level (or the value itself) whose items have text.
export function parseBus(text: string): BusLine[] {
  let json: unknown
  try {
    json = JSON.parse(text)
  } catch {
    return []
  }
  const candidates: unknown[] = Array.isArray(json)
    ? [json]
    : json && typeof json === 'object'
      ? Object.values(json)
      : []
  const list = candidates.find(
    (v): v is Record<string, unknown>[] =>
      Array.isArray(v) &&
      v.length > 0 &&
      v.every(i => i && typeof i === 'object' && typeof (i as { text?: unknown }).text === 'string'),
  )
  return (list ?? []).map(i => ({ at: typeof i.at === 'number' ? i.at : 0, text: i.text as string }))
}

export function mergeRecent(old: BusLine[], fresh: BusLine[], n = 3): BusLine[] {
  const seen = new Set<string>()
  return [...old, ...fresh]
    .filter(m => {
      const k = `${m.at}\n${m.text}`
      return seen.has(k) ? false : (seen.add(k), true)
    })
    .sort((a, b) => a.at - b.at)
    .slice(-n)
}

export function bandLine(m: BusLine, columns: number): string {
  const d = new Date(m.at)
  const hhmm = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
  const line = `${hhmm} ${m.text.split('\n')[0]}`
  return line.length > columns ? line.slice(0, Math.max(0, columns - 1)) + '…' : line
}
