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
    nixos-rebuild switch --flake .#g3 --target-host g3 --build-host g3 --use-remote-sudo --impure --accept-flake-config

hp:
    nixos-rebuild switch --flake .#hp --target-host hp --build-host hp --use-remote-sudo --impure --accept-flake-config

lms:
    nixos-rebuild switch --flake .#lms --target-host lms --build-host lms --use-remote-sudo --impure --accept-flake-config

dex5550:
    nixos-rebuild switch --flake .#dex5550 --target-host dex5550 --build-host dex5550 --use-remote-sudo --impure --accept-flake-config

p510:
    nixos-rebuild switch --flake .#p510 --target-host p510 --build-host p510 --use-remote-sudo --impure --accept-flake-config

p620:
    nixos-rebuild switch --flake .#p620 --target-host p620 --build-host p620 --use-remote-sudo --impure --accept-flake-config
    
razer:
    nixos-rebuild switch --flake .#razer --target-host razer --build-host razer --use-remote-sudo --impure --accept-flake-config


