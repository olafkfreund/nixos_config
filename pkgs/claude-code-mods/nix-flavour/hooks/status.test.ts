import { test, expect } from 'claude-code/testing'
import { formatStatus } from './status'

const K = '/nix/store/aaa-linux-6.12/bzImage'
const out = (kernel: string, booted: string) =>
  [
    'system-412-link',
    '/nix/store/xyz-nixos-system-p620-26.05.20261008.abc',
    kernel,
    booted,
  ].join('\n') + '\n'

test('matching kernels: host, generation, theme, no reboot marker', () => {
  const s = formatStatus(out(K, K), '"tokyo-night"\n')
  expect(s).toBe('❄ p620 · gen 412 · 🎨 tokyo-night')
})

test('mismatched kernels show the reboot marker', () => {
  const s = formatStatus(out(K, '/nix/store/bbb-linux-6.11/bzImage'), '"tokyo-night"\n')
  expect(s).toContain('⟳ new kernel, reboot')
})

test('missing theme file has no theme segment', () => {
  const s = formatStatus(out(K, K), '')
  expect(s).toBe('❄ p620 · gen 412')
})
