import { expect, test } from 'claude-code/testing'

import { bandLine, mergeRecent, parseBus } from './bus'

const payload = JSON.stringify({
  count: 2,
  hits: [
    { from: 'a', at: 1000, text: 'first', event_id: 'e1', thread: null },
    { from: 'b', at: 2000, text: 'second\nline two', event_id: 'e2', thread: null },
  ],
})

test('parseBus reads a search payload and survives garbage', () => {
  expect(parseBus(payload)).toEqual([
    { at: 1000, text: 'first' },
    { at: 2000, text: 'second\nline two' },
  ])
  expect(parseBus('not json')).toEqual([])
  expect(parseBus('{"count":0,"hits":[]}')).toEqual([])
  expect(parseBus('')).toEqual([])
})

test('mergeRecent dedupes, sorts and keeps the last n', () => {
  const old = [{ at: 2, text: 'b' }, { at: 1, text: 'a' }]
  const fresh = [{ at: 2, text: 'b' }, { at: 4, text: 'd' }, { at: 3, text: 'c' }]
  expect(mergeRecent(old, fresh)).toEqual([
    { at: 2, text: 'b' },
    { at: 3, text: 'c' },
    { at: 4, text: 'd' },
  ])
  expect(mergeRecent([], fresh, 1)).toEqual([{ at: 4, text: 'd' }])
})

test('bandLine prefixes the time, keeps the first line, truncates', () => {
  expect(bandLine({ at: 2000, text: 'hello\nworld' }, 80)).toMatch(/^\d\d:\d\d hello$/)
  const cut = bandLine({ at: 0, text: 'x'.repeat(100) }, 20)
  expect(cut.length).toBe(20)
  expect(cut.endsWith('…')).toBe(true)
})
