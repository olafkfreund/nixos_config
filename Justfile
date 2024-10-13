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
    nixos-rebuild switch --flake .#g3 --target-host g3 --build-host g3 --use-remote-sudo 

hp:
    nixos-rebuild switch --flake .#hp --target-host hp --build-host hp --use-remote-sudo 

lms:
    nixos-rebuild switch --flake .#lms --target-host lms --build-host lms --use-remote-sudo

dex5550:
    nixos-rebuild switch --flake .#dex5550 --target-host dex5550 --build-host dex5550 --use-remote-sudo

p510:
    nixos-rebuild switch --flake .#p510 --target-host p510 --build-host p510 --use-remote-sudo



