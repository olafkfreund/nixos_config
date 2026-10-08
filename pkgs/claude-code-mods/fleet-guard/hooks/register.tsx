import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import { bandLine, parseBus } from './bus'
import { classify } from './classify'

const BUS = 'agent-bus'
const recent = atom({ plugin: 'fleet-guard', key: 'recent' } as const, [])
const isHidden = atom({ plugin: 'fleet-guard', key: 'isHidden' } as const, false)

const textOf = (r: { content: { text?: string }[] }) => r.content.map(c => c.text ?? '').join('\n')

// `recent` reads the newest messages with no cursor, under the session's own
// bus identity, so polling never consumes what read_new would show the model.
async function poll($: EngineInterface) {
  try {
    const r = await $.mcp.call(BUS, 'recent', { limit: 3 })
    if (!r.isError) await update($, recent, () => parseBus(textOf(r)))
  } catch {
    // bus unreachable: leave the band as it is
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
    if (e.isInteractive) {
      void poll($)
      $.clock.every(60_000, () => poll($))
    }
    return next(e)
  })

  on('command.run', { command: 'announce' }, async ($, e) => {
    // Only a person posts to the shared room: not another plugin, not the SDK.
    if (e.origin.kind !== 'composer' && e.origin.kind !== 'bridge')
      return { text: '/announce only runs when you type it.' }
    const text = e.args.trim()
    if (!text) return { text: 'Usage: /announce <text>' }
    const r = await $.mcp.call(BUS, 'post', { text: '[' + host + '] ' + text })
    if (r.isError) return { text: 'Not posted: ' + textOf(r) }
    void poll($)
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
