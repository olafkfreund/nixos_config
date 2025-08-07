{ pkgs
, config
, ...
}:
with builtins; let
  mkHome = box: ".local/share/distrobox/${box}";
  boxes = {
    fedora = {
      home = mkHome "Fedora";
      alias = "fedora";
      img = "quay.io/fedora/fedora:42";
    };
    ubuntu = {
      home = mkHome "Ubuntu";
      alias = "ubuntu";
      img = "docker.io/library/ubuntu:25.04";
    };
    debian = {
      home = mkHome "Debian";
      alias = "debian";
      img = "quay.io/toolbx-images/debian-toolbox:12";
    };
  };

  mkBoxLinks = box:
    let
      ln = config.lib.file.mkOutOfStoreSymlink;
      links = [
        ".bashrc"
        ".zshrc"
        ".config/nushell"
        ".config/nvim"
        ".config/nix"
        ".config/starship.toml"
        ".local/"
        ".cache/"
      ];
    in
    listToAttrs (map
      (link: {
        name = "${box.home}/${link}";
        value = {
          source = ln "${config.home.homeDirectory}/${link}";
        };
      })
      links);

  mkBoxAlias =
    let
      db = "${pkgs.distrobox}/bin/distrobox";
    in
    box:
    pkgs.writeShellScriptBin box.alias ''
      if ! ${db} list | grep ${box.alias}; then
          ${db} create \
            --name "${box.alias}" \
            --home ${config.home.homeDirectory}/${box.home} \
            --image "${box.img}"
      fi

      ${db} enter ${box.alias}
    '';

  path = [
    "/bin"
    "/sbin"
    "/usr/bin"
    "/usr/sbin"
    "/usr/local/bin"
    "${pkgs.nix}/bin"
    "${pkgs.nushell}/bin"
    "${pkgs.zsh}/bin"
  ];

  shPath =
    path
    ++ [
      "$HOME/.local/bin"
    ];
in
{
  home.packages =
    let
      aliases = mapAttrs (_name: value: mkBoxAlias value) boxes;
    in
    (attrValues aliases) ++ [ pkgs.distrobox ];

  home.file =
    let
      links = mapAttrs (_name: value: mkBoxLinks value) boxes;
    in
    foldl' (x: y: x // y) { } (attrValues links);

  programs.bash.initExtra = ''
    if [[ -f "/run/.containerenv" ]]; then
      export PATH="${concatStringsSep ":" shPath}"
    fi
  '';

  programs.zsh.initContent = ''
    if [[ -f "/run/.containerenv" ]]; then
      export PATH="${concatStringsSep ":" shPath}"
    fi
  '';
}
