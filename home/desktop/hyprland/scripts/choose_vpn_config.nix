{ pkgs, ... }:

pkgs.writeShellScriptBin "choose_vpn_config" ''
    dir="$HOME/.config/rofi/launchers/type-2"
    theme='style-2'

    # base URL of control server (default https://controlplane.tailscale.com)
    TAILSCALE_LOGIN_SERVER="https://controlplane.tailscale.com"

    # Unix username to allow to operate on tailscaled without sudo
    TAILSCALE_OPERATOR="''$(whoami)"

    # case-insensitive matching, 7 rows, select row with index 1 by default (the "up" option)
    ROFI_ARGS="-theme "''${dir}/''${theme}.rasi" -p Tailscale -i -lines 7 -selected-row 1"

    # define common options
    declare -A options
    options[" up"]="up \
                     --login-server ''${TAILSCALE_LOGIN_SERVER} \
                     --operator ''${TAILSCALE_OPERATOR} \
                     --accept-routes \
                     --shields-up \
                     --reset"
    options[" down"]="down"

    # get tailscale status, then add one rofi option per available exit node
    status=$(curl --silent --fail --unix-socket /var/run/tailscale/tailscaled.sock http://local-tailscaled.sock/localapi/v0/status)
    for dnsname in $(echo ''${status} | jq --raw-output '.Peer[] | select(.ExitNodeOption) | .DNSName'); do
        options[" up (''${dnsname} as exit node)"]="up \
                                                    --login-server ''${TAILSCALE_LOGIN_SERVER} \
                                                    --operator ''${TAILSCALE_OPERATOR} \
                                                    --exit-node ''${dnsname} \
                                                    --accept-routes \
                                                    --shields-up \
                                                    --reset"
    done

    main() {
        # print the options separated by newline characters, sort them, then call rofi
        result=$(echo -e "$(printf "%s\n" "''${!options[@]}" | sort)" | rofi -dmenu $ROFI_ARGS)

        # rofi exit code == 0: normal operation
        # 10 <= exit code <= 28: keybindings used
        # anything else: canceled or something unforeseen happened
        if [[ $? == 0 || ($? -ge 10 && $? -le 28) ]]; then
            command=''${options[$result]}
            tailscale $command

            # alternative if you want to use polkit for rights elevation instead of the '--operator' option:
            # pkexec tailscale $command
        fi
    }

    main
''
