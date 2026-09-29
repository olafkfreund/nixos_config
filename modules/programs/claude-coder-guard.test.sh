#!/usr/bin/env bash
# Run: bash modules/programs/claude-coder-guard.test.sh   (needs jq on PATH)
# Checks the coder guard (#2079) against commands it must block and commands
# it must let through. Exit 1 on any mismatch.
here=$(dirname "$0")
guard=$(mktemp)
trap 'rm -f "$guard"' EXIT
sed 's#@jq@#jq#' "$here/claude-coder-guard.sh" >"$guard"

fail=0
t() {
  printf '{"tool_input":{"command":%s}}' "$(jq -Rn --arg c "$2" '$c')" | bash "$guard" 2>/dev/null
  r=$?
  if [ "$r" != "$1" ]; then
    echo "FAIL got=$r want=$1: $2"
    fail=1
  fi
}

while IFS= read -r c; do t 2 "$c"; done <<'BLOCK'
nixos-rebuild switch --flake .#p620
nixos-rebuild --help
sudo nh os switch .
nhs p620
/nix/var/nix/profiles/system/activate
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
nix-env -p /nix/var/nix/profiles/system --set /nix/store/x
just quick-deploy p620
just deploy-via-p620 razer
just p510
just --justfile Justfile p620
just update-commit-deploy
nix-collect-garbage -d
nix store gc
nix store optimise
nix-store --gc
nix-store --optimise
nix-store --delete /nix/store/x
reboot
sudo reboot
sudo -n reboot
env reboot
timeout 5 reboot
bash -c reboot
bash -c 'sudo reboot'
(reboot)
true; poweroff
x && reboot
/run/current-system/sw/bin/reboot
shutdown -h now
halt
systemctl reboot
systemctl halt
systemctl kexec
systemctl restart foo
systemctl --user stop x
systemctl try-restart foo
systemctl reload-or-restart foo
systemctl enable --now foo
git commit -m x
cd x && git commit -qa -F -
git -C . push
git -c user.name=x commit -m y
git checkout main
git switch -c x
git stash
git stash push
git stash pop
git reset --hard HEAD
git rebase main
git merge x
git branch -D x
git update-ref refs/heads/x HEAD
git restore file
git clean -fdx
BLOCK

while IFS= read -r c; do t 0 "$c"; done <<'ALLOW'
just check-syntax
just test-host razer
just test-host p620
just validate
nix build .#x
nix eval --raw .#x
nix flake check
git status
git diff
git diff HEAD -- switch.nix
git log --oneline -3
git log --grep commit
git log -- stash.nix
git add -A
git stash list
git branch --show-current
systemctl status foo
systemctl --user list-units
systemctl is-active x && echo started
grep -rn restart modules/
rg 'git push' docs/
grep -rn "git commit" .
rg reboot docs/
rg -n nhs docs/
ls | grep nhs
echo nhs-config
cat plan/x.md
nix-env -iA nixpkgs.systemd
ALLOW

[ "$fail" = 0 ] && echo "coder guard: all cases pass"
exit $fail
