import type { EngineInterface, Register } from 'claude-code'
import { formatStatus } from './status'

const WORDS = [
  'Evaluating thunks', 'Realising derivations', 'Substituting from cache.nixos.org',
  'Fleeing infinite recursion', 'Bumping flake.lock', 'Hashing the NAR', 'Reaching the fixpoint',
  'Overriding attrs', 'Fetching tarballs', 'Pinning inputs', 'Consulting the overlays',
  'Collecting garbage', 'Patching shebangs', 'Wrapping programs', 'Rebasing on nixos-unstable',
]
const DONE = ['Realised', 'Evaluated', 'Substituted', 'Built', 'Activated', 'Garbage-collected', 'Flaked']
const pick = (xs: string[]) => xs[Math.floor(Math.random() * xs.length)]!

async function refresh($: EngineInterface) {
  const r = await $.process.run([
    'readlink', '/nix/var/nix/profiles/system', '/run/current-system',
    '/run/current-system/kernel', '/run/booted-system/kernel',
  ])
  const theme = await $.fs.read('/home/olafkfreund/.config/nixos/nixarchy-theme.nix').catch(() => '')
  $.ui.status(formatStatus(r.stdout, theme))
}

export const register: Register = on => {
  let word = pick(WORDS)

  on('session.start', async ($, e, next) => {
    await refresh($)
    $.clock.every(60_000, () => refresh($))
    return next(e)
  })

  on('prompt.submit', ($, e, next) => {
    word = pick(WORDS)
    return next(e)
  })

  on('ui.render', { component: 'Spinner' }, ($, e, next) =>
    e.props.message === null ? next({ ...e, props: { ...e.props, word } }) : next(e))

  on('ui.render', { component: 'TurnDuration' }, ($, e, next) =>
    next({ ...e, props: { ...e.props, word: DONE[[...e.requestId].reduce((n, c) => n + c.charCodeAt(0), 0) % DONE.length]! } }))
}
