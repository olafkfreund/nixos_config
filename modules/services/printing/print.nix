{ self, config, pkgs, ... }: {
# Enable CUPS to print documents.
services.printing = {
  enable = true;
  };
}
