export function formatStatus(readlinkStdout: string, themeFile: string): string {
  const [profile = '', current = '', kernel, booted] = readlinkStdout.trim().split('\n')
  const host = /nixos-system-([^-]+)-/.exec(current)?.[1] ?? '?'
  const gen = /system-(\d+)-link/.exec(profile)?.[1] ?? '?'
  const theme = themeFile.match(/^"([^"]+)"/m)?.[1]
  return [`❄ ${host}`, `gen ${gen}`, kernel !== booted ? '⟳ new kernel, reboot' : '', theme ? `🎨 ${theme}` : '']
    .filter(Boolean).join(' · ')
}
