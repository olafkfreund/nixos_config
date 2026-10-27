# Enables Omarchy plugins once per host from a post-boot hook, the way
# nixarchy does for its defaultPlugins. A marker per id means turning a plugin
# off later in Setup > Plugins sticks. The hook never writes shell.json.
# Use: local.omarchy.enableOnce = [ "<plugin id>" ]; (shared with #2505)
{ pkgs, lib, ... }:
{
  home-manager.sharedModules = [
    ({ config, ... }:
      let
        ids = config.local.omarchy.enableOnce;
      in
      {
        options.local.omarchy.enableOnce = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Omarchy plugin ids to enable once per host.";
        };

        config.xdg.configFile."omarchy/hooks/post-boot.d/enable-once" = lib.mkIf (ids != [ ]) {
          executable = true;
          text = ''
            #!${pkgs.bash}/bin/bash
            # omarchy-shell and omarchy-plugin-enable come from the session PATH.
            export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.systemd ]}:$PATH
            state="''${XDG_STATE_HOME:-$HOME/.local/state}/nixarchy-local/enabled-once"
            export OMARCHY_SHELL_IPC_TIMEOUT=''${OMARCHY_SHELL_IPC_TIMEOUT:-30s}

            todo=()
            for id in ${lib.escapeShellArgs ids}; do
              [ -e "$state/$id" ] || todo+=("$id")
            done
            [ "''${#todo[@]}" -eq 0 ] && exit 0

            up=
            for _ in $(seq 120); do
              if omarchy-shell shell ping >/dev/null 2>&1; then
                up=1
                break
              fi
              sleep 1
            done
            [ -n "$up" ] || exit 0

            omarchy-shell shell rescanPlugins || true
            for id in "''${todo[@]}"; do
              if out=$(omarchy-plugin-enable "$id" 2>&1); then
                mkdir -p "$state"
                touch "$state/$id"
              else
                printf '%s: %s\n' "$id" "$out" | systemd-cat -t omarchy-enable-once
              fi
            done
          '';
        };
      })
  ];
}
