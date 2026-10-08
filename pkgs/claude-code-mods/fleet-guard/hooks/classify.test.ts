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
