import { expect, test } from 'claude-code/testing'

import { classify } from './classify'

test('denies the two footguns', () => {
  expect(classify('git commit -m "run `just p510` later"').kind).toBe('deny')
  expect(classify('git commit -m "fix $(date)"').kind).toBe('deny')
  expect(classify('git commit -am "fix `x`"').kind).toBe('deny')
  expect(classify('git -C ../wt commit --message "fix `x`"').kind).toBe('deny')
  expect(classify('home-manager switch --flake .').kind).toBe('deny')
  expect(classify('cd ~ && home-manager --flake . switch').kind).toBe('deny')
})

test('denies an unthrottled gh watch, wherever it sits in the command', () => {
  expect(classify('gh run watch 123').kind).toBe('deny')
  expect(classify('gh run watch 123 --exit-status').kind).toBe('deny')
  expect(classify('cd wt && gh run watch $id --exit-status >/dev/null').kind).toBe('deny')
  expect(classify('gh run watch 123 --interval 5').kind).toBe('deny')
  expect(classify('gh run watch 123 -i 10').kind).toBe('deny')
  expect(classify('gh pr checks 42 --watch').kind).toBe('deny')
  expect(classify('x; gh pr checks 42 --watch --interval 10').kind).toBe('deny')
  expect(classify('gh run watch 1 --interval 60; gh run watch 2').kind).toBe('deny')
})

test('passes a throttled watch, a plain checks call, and the words in prose', () => {
  expect(classify('gh run watch 123 --interval 60').kind).toBe('pass')
  expect(classify('gh run watch 123 --interval=30 --exit-status').kind).toBe('pass')
  expect(classify('gh run watch 123 -i 45').kind).toBe('pass')
  expect(classify('gh pr checks 42').kind).toBe('pass')
  expect(classify('gh pr checks 42 --json name,state').kind).toBe('pass')
  expect(classify('gh pr checks 42 --watch --interval 60').kind).toBe('pass')
  expect(classify('grep -rn "gh run watch" docs').kind).toBe('pass')
  expect(classify('gh run view 123 --log-failed').kind).toBe('pass')
})

test('passes everything else, deploys included (the managed guards own those)', () => {
  expect(classify('nix build .#nixosConfigurations.p620.config.system.build.toplevel').kind).toBe('pass')
  expect(classify('systemctl status sshd').kind).toBe('pass')
  expect(classify('git commit -m "docs: mention nhs"').kind).toBe('pass')
  expect(classify("git commit -F - <<'MSG'\nfix `x`\nMSG").kind).toBe('pass')
  expect(classify("git commit -m \"$(cat <<'EOF'\nfix `x`\nEOF\n)\"").kind).toBe('pass')
  expect(classify('git commit -F msg.txt  # never run home-manager switch').kind).toBe('pass')
  expect(classify('grep -rn "home-manager switch" docs').kind).toBe('pass')
  expect(classify('just p620').kind).toBe('pass')
  expect(classify('sudo nix-collect-garbage -d').kind).toBe('pass')
})
