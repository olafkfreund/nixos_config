deploy:
    nh os switch

update:
    nh os update

history:
    nix profile history --profile /nix/var/nix/profiles/system

repl:
    nix repl -f flake:nixpkgs

gc:
    sudo nix-collect-garbage --delete-old

g3:
    nixos-rebuild switch --flake .#g3 --target-host g3 --build-host g3 --use-remote-sudo --show-trace

hp:
    nixos-rebuild switch --flake .#hp --target-host hp --build-host hp --use-remote-sudo --show-trace

lms:
    nixos-rebuild switch --flake .#lms --target-host lms --build-host lms --use-remote-sudo --show-trace

dx5550:
    nixos-rebuild switch --flake .#dx5550 --target-host dx5550 --build-host hp --use-remote-sudo --show-trace



