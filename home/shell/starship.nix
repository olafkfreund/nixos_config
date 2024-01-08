{ ... }: 
{
# starship - an customizable prompt for any shell
programs.starship = {
  enable = true;
  # custom settings
  settings = {
        format = let
          git = "$git_branch$git_commit$git_state$git_status";
        in ''
          $username[@](purple)$hostname $directory (${git}) ($cmd_duration) $fill ($nix_shell)
          $character
        '';
      # custom prompt
        azure = {
        format = "on [$symbol($subscription)]($style)";
        symbol = "󰠅 ";
        style = "blue bold"
        };

        azure.subscription_aliases = {
          very-long-subscription-name = "vlsn";
        };

        container = {
          format = "[$symbol \[$name\]]($style) ";
          symbol = "📦 "
        };

        username = {
          style_user = "white bold";
          style_root = "black bold";
          format = "user: [$user]($style) ";
          show_always = true;
          style_user = "bold cyan";
        };

        hostname = {
          format = "[$hostname]($style)";
          ssh_only = false;
          style = "bold green";
        };

        directory = {
          format = "[$path]($style)([$read_only]($read_only_style))";
          style = "bold yellow";
        };

        cmd_duration = {
          format = "took [$duration]($style)";
          style = "bold yellow";
        };

        nix_shell = {
          format = "[($name \\(develop\\) <- )$symbol]($style)";
          impure_msg = "";
          symbol = " ";
          style = "bold blue";
        };

        character = {
          error_symbol = "[λ](bold red)";
          success_symbol = "[λ](bold green)";
        };

        fill = {
          symbol = " ";
          disabled = false;
        };

        docker_context = {
          format = "via [🐋 $context](blue bold)"
        };

        git_branch = {
          symbol = "🌱 ";
          truncation_length = "4";
          truncation_symbol = "''";
          ignore_branches = "['master', 'main']";
        };

        git_commit = {
          format = "[$hash]($style)";
          style = "bold yellow";
          only_detached = true;
          tag_symbol = "🏷 ";
        };

        git_state = {
          format = "[\($state( $progress_current of $progress_total)\)]($style) ";
          cherry_pick = "[🍒 PICKING](bold red)";
        };

        git_metrics = {
          added_style = "bold blue";
          format = "[+$added]($added_style)/[-$deleted]($deleted_style) ";
        };

        git_status = {
          conflicted = "🏳";
          ahead = "🏎💨";
          behind = "😰";
          diverged = "😵";
          up_to_date = "✓";
          untracked = "🤷";
          stashed = "📦";
          modified = "📝";
          staged = "[++\($count\)](green)";
          renamed = "👅";
          deleted = "🗑";
        };

        helm = {
          format = "via [⎈ $version](bold white) ";
        };

        hostname = {
          ssh_only = false;
          format = "[$ssh_symbol](bold blue) on [$hostname](bold red) ";
          trim_at = ".companyname.com";
          disabled = false;
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
          format = "on [$symbol($profile )(\($region\) )]($style)";
          style = "bold blue";
          symbol = "🅰 ";
        };

        aws.region_aliases = {
          ap-southeast-2 = "au";
          us-east-1 = "va";
        };

        character = {
          success_symbol = "[♥](bold green)";
          error_symbol = "[♥](bold red)";
          vimcmd_symbol = "[♡](bold purple)";
          vimcmd_replace_symbol = "[♡](bold green)";
          vimcmd_replace_one_symbol = "[♡](bold green)";
          vimcmd_visual_symbol = "[♡](bold yellow)";
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
        nix_shell.symbol = "nix ";
        ocaml.symbol = "ml ";
        opa.symbol = "opa ";
        aws.symbol = "  ";
        conda.symbol = " ";
        dart.symbol = " ";
        # directory.read_only = " ";
        docker_context.symbol = " ";
        elixir.symbol = " ";
        elm.symbol = " ";
        gcloud.symbol = " ";
        git_branch.symbol = " ";
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
};

}
