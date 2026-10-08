import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { BusLine } from '../types'
import { bandLine, mergeRecent, parseBus } from './bus'
import { classify } from './classify'

const BUS = 'agent-bus'
const recent = atom({ plugin: 'fleet-guard', key: 'recent' } as const, [])
const isHidden = atom({ plugin: 'fleet-guard', key: 'isHidden' } as const, false)

const textOf = (r: { content: { text?: string }[] }) => r.content.map(c => c.text ?? '').join('\n')

async function poll($: EngineInterface, host: string) {
  try {
    const r = await $.mcp.call(BUS, 'read_new', { agent: 'fleet-guard-' + host, limit: 20 })
    const old = ((await $.store.get('recent')) as BusLine[] | undefined) ?? []
    const merged = mergeRecent(old, parseBus(textOf(r)))
    await $.store.set('recent', merged)
    await update($, recent, () => merged)
  } catch {
    // bus unreachable: leave the list as it is
  }
}

export const register: Register = on => {
  let host = 'unknown'

  on('session.start', async ($, e, next) => {
    const system = await $.process.run(['readlink', '/run/current-system'])
    host = /nixos-system-([^-]+)-/.exec(system.stdout)?.[1] ?? 'unknown'
    await $.command.register({
      name: 'announce',
      description: 'Post to #agents as this host',
      argumentHint: '<text>',
    })
    await poll($, host)
    $.clock.every(60_000, () => poll($, host))
    return next(e)
  })

  on('command.run', { command: 'announce' }, async ($, e) => {
    const text = e.args.trim()
    if (!text) return { text: 'Usage: /announce <text>' }
    await $.mcp.call(BUS, 'post', { text: '[' + host + '] ' + text })
    await poll($, host)
    return { text: 'Posted to #agents: ' + text }
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const list = await read($, recent)
    if (e.props.hasSurvey || list.length === 0 || (await read($, isHidden))) return next(e)

    const { Box, Button, Text } = $.ui.resolve(e)
    return (
      <Box flexDirection="column">
        {list.map(m => (
          <Text dimColor>{bandLine(m, e.props.bodyColumns)}</Text>
        ))}
        <Button key="hide" label="Hide" onPress={() => update($, isHidden, () => true)} />
      </Box>
    )
  })

  on('tool.call', { tool: 'Bash' }, ($, e, next) => {
    const verdict = classify(e.command)
    return verdict.kind === 'deny' ? { deny: 'fleet-guard: ' + verdict.reason } : next(e)
  }).catch(($, e, next) => next(e))
}
