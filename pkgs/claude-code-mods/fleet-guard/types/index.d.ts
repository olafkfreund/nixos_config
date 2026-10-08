export type BusLine = { at: number; text: string }

declare module 'claude-code' {
  interface PluginState {
    'fleet-guard': { recent: BusLine[]; isHidden: boolean }
  }
}
