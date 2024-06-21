{ lib, ... }: {
  # starship - an customizable prompt for any shell
  programs.starship = {
    enable = true;
    # custom settings
    enableBashIntegration = false;
    enableZshIntegration = true;
    settings = {
      add_newline = true;
      format = lib.concatStrings [
        "[](fg:color_bg3)"
        "[ ](fg:color_fg0 bg:color_bg3)"
        "($container)"
        "$os"
        "$hostname"
        "[ ](fg:color_fg0 bg:color_bg3)"
        "[ ](bold fg:color_bg1 bg:color_orange)"
        "[ ](fg:color_orange bg:color_bg3)"
        "$username"
        "$directory"
        "$shell"
        # "($cmd_duration)"
        "$fill"
        "($azure)"
        "($aws)"
        "($nix_shell)"
        "$git_branch"
        "$git_commit"
        "$git_status"
        "$time"
      ];
      palette = "gruvbox_dark";

      palettes.gruvbox_dark = {
        color_fg0 = "#fbf1c7";
        color_bg1 = "#3c3836";
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
        format = "[ ](fg:color_bg3)[ $symbol($subscription)]($style)[ ](bg:color_bg1)[  ](fg:color_bg1 bg:color_blue)[ ](fg:color_blue)";
        symbol = "󰠅 ";
        style = "bg:color_bg3 fg:color_fg0";
      };

      azure.subscription_aliases = {
        very-long-subscription-name = "vlsn";
      };

      container = {
        format = "[$symbol]($style)";
        symbol = " ";
        style = "fg:color_fg0 bg:color_bg3";
      };

      time = {
        disabled = false;
        style = "fg:color_fg0 bg:color_bg3";
        format = "[](fg:color_orange)[ ](bold fg:color_bg1 bg:color_orange)[ $time]($style)[](fg:color_bg3)";
      };
      os = {
        format = "[$symbol]($style)";
        style = "fg:color_fg0 bg:color_bg3";
        disabled = false;
      };

      os.symbols = {
        NixOS = " ";
        OpenBSD = "🐡 ";
        Ubuntu = " ";
        Debian = " ";
        Arch = " ";
        Alpine = " ";
        Macos = " ";
        Fedora = " ";
        Redhat = " ";
        Windows = " ";
      };

      env_var = {
        variable = "CONTAINER_ID";
        symbol = "📦 ";
        style = "bold red";
        format = "running on: [$env_value]($style)";
      };

      username = {
        style_user = "bg:color_bg3 fg:color_fg0";
        style_root = "bg:color_bg3 fg:color_fg0";
        format = "[$user ]($style)[ ](bold fg:color_bg1 bg:color_blue)[](fg:color_blue bg:color_bg3)";
        show_always = true;
      };

      hostname = {
        format = "[$ssh_symbol]($style)[$hostname ]($style)";
        ssh_only = false;
        style = "fg:color_fg0 bg:color_bg3";
      };

      directory = {
        format = "[ $path]($style)([$read_only]($read_only_style))[ ](bg:color_bg3)[ ](bold bg:color_green fg:color_bg1)[](fg:color_green bg:color_bg3)";
        style = "fg:color_fg0 bg:color_bg3";
        truncation_length = 8;
        truncation_symbol = "…/";
      };

      cmd_duration = {
        format = "[ ](bg:color_bg3)[  ](fg:color_bg1 bg:color_purple)[ ](fg:color_purple)";
        style = "fg:color_fg0 bg:color_bg3";
      };

      shell = {
        zsh_indicator = " #zsh";
        bash_indicator = " #!bash";
        powershell_indicator = "_";
        unknown_indicator = "mystery shell";
        style = "fg:color_fg0 bg:color_bg3";
        disabled = false;
        format = "[$indicator ]($style)[ ](fg:color_bg1 bg:color_yellow)[](fg:color_yellow)";
      };

      nix_shell = {
        format = "[](fg:color_fg0 bg:color_bg3)[($name \\(develop\\) <- )$symbol]($style)[](fg:color_yellow)";
        impure_msg = "";
        symbol = "  ";
        style = "bg:color_fg0 fg:color_bg3";
      };

      fill = {
        symbol = " ";
        disabled = false;
      };

      docker_context = {
        format = "via [🐋 $context](blue bold)";
      };

      git_branch = {
        symbol = "🌱 ";
        format = "[ ](fg:color_purple)[ ](bg:color_purple fg:color_bg1)[$symbol$branch(:$remote_branch)]($style)";
        style = "fg:color_fg0 bg:color_bg3";
        truncation_symbol = "...";
      };

      git_commit = {
        format = "[$hash]($style)";
        style = "bg:color_bg3 fg:color_fg0";
        only_detached = true;
        tag_symbol = "🏷 ";
      };

      git_state = {
        format = "[\($state( $progress_current of $progress_total)\)]($style) ";
        cherry_pick = "[🍒 PICKING](bold red)";
        style = "bg:color_bg3 fg:color_fg0";
      };

      git_metrics = {
        added_style = "bold blue";
        format = "[+$added]($added_style)/[-$deleted]($deleted_style) ";
        style = "bg:color_bg3 fg:color_fg0";
      };

      git_status = {
        conflicted = " 🏳";
        ahead = " 🏎💨";
        behind = " 😰";
        diverged = " 😵";
        up_to_date = " ✓";
        untracked = " 🤷";
        stashed = " 📦";
        modified = " 📝";
        staged = "[++\($count\)](green)";
        renamed = " 👅";
        deleted = " 🗑";
        format = "[[($all_status$ahead_behind) ](fg:color_fg0 bg:color_bg3)]($style)[ ](fg:color_bg3)";
        style = "bg:color_bg3";
      };

      helm = {
        format = "via [⎈ $version](bold white) ";
      };

      kubernetes = {
        format = "on [⛵ ($user on )($cluster in )$context \($namespace\)](dimmed green) ";
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
        style = "bold green";
        symbol = "👩‍💻 ";
        disabled = false;
      };

      terraform = {
        format = "[🏎💨 $version$workspace]($style) ";
      };

      aws = {
        format = "[ ](fg:color_blue)[  ](bg:color_blue fg:color_bg1)[ $symbol ($profile)(\($region\)) ]($style)[ ](fg:color_bg3)";
        style = "bg:color_bg3 fg:color_fg0";
        symbol = "󰸏";
      };

      aws.region_aliases = {
        eu-west-2 = "eu-w2";
        eu-west-1 = "eu-w1";
      };

      character = {
        success_symbol = "[](bold green)";
        error_symbol = "[](bold red)";
        vimcmd_symbol = "[](bold purple)";
        vimcmd_replace_symbol = "[](bold green)";
        vimcmd_replace_one_symbol = "[](bold green)";
        vimcmd_visual_symbol = "[](bold yellow)";
      };

      bun.symbol = "bun ";
      c.symbol = "C ";
      cobol.symbol = "cobol ";
      # conda.symbol = "conda ";
      crystal.symbol = "cr ";
      cmake.symbol = "cmake ";
      daml.symbol = "daml ";
      # dart.symbol = "dart ";
      deno.symbol = "deno ";
      dotnet.symbol = ".NET ";
      directory.read_only = " ro";
      # elixir.symbol = "exs ";
      # elm.symbol = "elm ";
      # golang.symbol = "go ";
      guix_shell.symbol = "guix ";
      # hg_branch.symbol = "hg ";
      # java.symbol = "java ";
      # julia.symbol = "jl ";
      kotlin.symbol = "kt ";
      lua.symbol = "lua ";
      # nodejs.symbol = "nodejs ";
      memory_usage.symbol = "memory ";
      meson.symbol = "meson ";
      nim.symbol = "nim ";
      ocaml.symbol = "ml ";
      opa.symbol = "opa ";
      conda.symbol = " ";
      dart.symbol = " ";
      # directory.read_only = " ";
      docker_context.symbol = " ";
      elixir.symbol = " ";
      elm.symbol = " ";
      gcloud.symbol = " ";
      golang.symbol = " ";
      hg_branch.symbol = " ";
      java.symbol = " ";
      julia.symbol = " ";
      # memory_usage.symbol = " ";
      # nim.symbol = " ";
      nodejs.symbol = " ";
      package.symbol = "pkg ";
      perl.symbol = " ";
      php.symbol = " ";
      python.symbol = " ";
      ruby.symbol = " ";
      rust.symbol = " ";
      scala.symbol = " ";
      shlvl.symbol = "";
      swift.symbol = "ﯣ ";
      # terraform.symbol = "行";
    };
  };
}
