{ lib
, config
, ...
}:
with lib; let
  cfg = config.cli.starship;
in
{
  options.cli.starship = {
    enable = mkEnableOption {
      default = true;
      description = "starship";
    };
  };
  config = mkIf cfg.enable {
    # starship - an customizable prompt for any shell
    programs.starship = {
      enable = true;
      # custom settings
      enableBashIntegration = false;
      enableZshIntegration = true;
      settings = {
        add_newline = true;
        format = lib.concatStrings [
          "[────────────────────────────────────────────────────────────────────────────────](dimmed fg:color_bg3)"
          "$line_break"
          "($container)"
          "$os"
          "$hostname"
          "$username"
          "$directory"
          "$shell"
          "$sudo"
          "$cmd_duration"
          "$fill"
          "($nix_shell)"
          "$git_branch"
          "$git_commit"
          "$git_status"
          "$line_break"
          "$character"
        ];
        palette = lib.mkForce "gruvbox_dark";

        palettes.gruvbox_dark = {
          color_fg0 = "#fbf1c7";
          color_bg1 = "#3c3836";
          color_bg0 = "#282828";
          color_bg3 = "#665c54";
          color_blue = "#83a598";
          color_aqua = "#689d6a";
          color_green = "#98971a";
          color_orange = "#d65d0e";
          color_purple = "#b16286";
          color_red = "#cc241d";
          color_yellow = "#d79921";
        };

        azure = {
          format = "$symbol($subscription) ";
          symbol = "󰠅 ";
          style = "fg:color_blue";
        };

        azure.subscription_aliases = {
          very-long-subscription-name = "vlsn";
        };

        container = {
          format = "$symbol";
          symbol = " ";
          style = "fg:color_fg0";
        };

        time = {
          disabled = false;
          style = "fg:color_fg0";
          format = " $time";
        };

        os = {
          format = "$symbol";
          style = "fg:color_fg0";
          disabled = false;
        };

        os.symbols = {
          NixOS = " ";
          OpenBSD = "🐡 ";
          Ubuntu = " ";
          Debian = " ";
          Arch = " ";
          Alpine = " ";
          Macos = " ";
          Fedora = " ";
          Redhat = " ";
          Windows = " ";
        };

        env_var = {
          variable = "CONTAINER_ID";
          symbol = "📦 ";
          style = "bold red";
          format = "running on: [$env_value]($style)";
        };

        username = {
          style_user = "bold fg:color_green";
          style_root = "bold fg:color_red";
          format = "$user ";
          show_always = false;
          aliases = {
            olafkfreund = "olaf";
          };
        };

        hostname = {
          format = "$ssh_symbol$hostname ";
          ssh_only = true;
          detect_env_vars = [ ''!TMUX'' ];
          style = "bold fg:color_purple";
        };

        directory = {
          format = "$path($read_only) ";
          style = "bold fg:color_blue";
          home_symbol = "~";
          read_only = "󰉐";
          read_only_style = "fg:color_red";
          truncation_length = 2;
          truncation_symbol = "…/";
        };

        cmd_duration = {
          min_time = 1000; # Show for commands taking more than 1s
          show_milliseconds = true;
          format = "⏱ $duration ";
          style = "bold fg:color_yellow";
          disabled = false; # Enable to show command duration
        };

        shell = {
          zsh_indicator = "zsh";
          bash_indicator = "bash";
          powershell_indicator = "pwsh";
          unknown_indicator = "shell";
          style = "fg:color_aqua";
          disabled = false;
          format = "$indicator ";
        };

        nix_shell = {
          format = "($name develop) $symbol";
          impure_msg = "devbox";
          symbol = "❄️";
          style = "bold fg:color_blue";
        };

        fill = {
          symbol = " ";
          disabled = false;
        };

        docker_context = {
          format = "via 🐋 $context ";
          style = "fg:color_blue";
        };

        git_branch = {
          symbol = " ";
          format = "$symbol$branch(:$remote_branch) ";
          style = "bold fg:color_purple";
          truncation_symbol = "...";
        };

        git_commit = {
          format = "$hash ";
          style = "fg:color_orange";
          only_detached = true;
          tag_symbol = "🏷";
        };

        git_state = {
          format = "($state( $progress_current of $progress_total)) ";
          cherry_pick = "🍒 PICKING";
          style = "fg:color_red";
        };

        git_metrics = {
          added_style = "bold blue";
          format = "+$added/-$deleted ";
          style = "fg:color_fg0";
        };

        git_status = {
          conflicted = "🏳";
          ahead = "⬆";
          behind = "⬇";
          diverged = "⬍";
          up_to_date = "✓";
          untracked = "?";
          stashed = "📦";
          modified = "!";
          staged = "+$count";
          renamed = "»";
          deleted = "✘";
          format = "($all_status$ahead_behind) ";
          style = "bold fg:color_red";
        };

        helm = {
          format = "⎈ $version ";
          style = "fg:color_fg0";
        };

        kubernetes = {
          format = "⛵ ($user on )($cluster in )$context ($namespace) ";
          style = "fg:color_green";
          disabled = false;
        };

        kubernetes.context_aliases = {
          "dev.local.cluster.k8s" = "dev";
          ".*/openshift-cluster/.*" = "openshift";
          "gke_.*_(?P<var_cluster>[\w-]+)" = "gke-$var_cluster";
        };

        kubernetes.user_aliases = {
          "dev.local.cluster.k8s" = "dev";
          "root/.*" = "root";
        };

        sudo = {
          style = "fg:color_red";
          symbol = "🧙";
          disabled = true;
          format = "$symbol ";
        };

        terraform = {
          format = "🏎💨 $version$workspace ";
          style = "fg:color_purple";
        };

        aws = {
          format = "󰸏 $symbol ($profile)($region) ";
          style = "fg:color_orange";
          symbol = "󰸏";
        };

        aws.region_aliases = {
          eu-west-2 = "eu-w2";
          eu-west-1 = "eu-w1";
        };

        character = {
          success_symbol = "[❯](bold green)";
          error_symbol = "[❯](bold red)";
          vimcmd_symbol = "[❮](bold purple)";
          vimcmd_replace_symbol = "[❮](bold yellow)";
          vimcmd_replace_one_symbol = "[❮](bold yellow)";
          vimcmd_visual_symbol = "[❮](bold blue)";
        };

        line_break = {
          disabled = false;
        };


        bun.symbol = "bun ";
        c.symbol = "C ";
        cobol.symbol = "cobol ";
        crystal.symbol = "cr ";
        cmake.symbol = "cmake ";
        daml.symbol = "daml ";
        deno.symbol = "deno ";
        dotnet.symbol = ".NET ";
        guix_shell.symbol = "guix ";
        kotlin.symbol = "kt ";
        lua.symbol = "lua ";
        memory_usage.symbol = "memory ";
        meson.symbol = "meson ";
        nim.symbol = "nim ";
        ocaml.symbol = "ml ";
        opa.symbol = "opa ";
        conda.symbol = " ";
        dart.symbol = " ";
        docker_context.symbol = " ";
        elixir.symbol = " ";
        elm.symbol = " ";
        gcloud.symbol = " ";
        golang.symbol = " ";
        hg_branch.symbol = " ";
        java.symbol = " ";
        julia.symbol = " ";
        nodejs.symbol = " ";
        package.symbol = "pkg ";
        perl.symbol = " ";
        php.symbol = " ";
        python.symbol = " ";
        ruby.symbol = " ";
        rust.symbol = " ";
        scala.symbol = " ";
        shlvl.symbol = "";
        swift.symbol = "ﯣ ";
      };
    };
  };
}
