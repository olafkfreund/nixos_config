# nixarchy-bbs — a BBS delivered over SSH, for Nixarchy contributors and the
# coding agents that work on their behalf.
#
# The product is one binary (pkgs/nixarchy-bbs) running a charmbracelet/wish
# SSH server that routes on the SSH *username*: `<name>@` opens the member hub
# (inbox, threaded NNTP news, SFTP file area, arcade), `msg@` is store-and-
# forward notes, `admin@` is the operator console. Identity is the SSH public
# key's fingerprint — there are no passwords anywhere — which is precisely why
# it suits agents: an agent already holds exactly that credential, and
# `ssh msg@<host> <user> "<note>"` needs no PTY and no interaction.
#
# Membership, and where GitHub comes in
# -------------------------------------
# Two doors, and by default both are open:
#
#   • `ssh join@<host>` — upstream's self-service signup, anyone with a key.
#   • the GitHub sync — someone opens an issue on `memberRepo`, a maintainer
#     applies `memberLabel`, and nixarchy-bbs-sync.timer fetches that author's
#     published keys from https://github.com/<handle>.keys and calls
#     `agentbbs provision-user`. Their account exists before they first
#     connect; they skip onboarding entirely and land straight in the hub.
#
# The sync is the interesting one: it makes membership reviewable and revocable
# in the issue tracker, and nobody has to hand-copy a public key. It works fine
# alongside open signup — it is a fast path for known contributors, not a gate.
#
# `closedRegistration` turns it into a gate: join@ then refuses keys the store
# does not know, and a labelled issue becomes the only way in. Off for now,
# deliberately — an empty board behind a locked door stays empty.
#
# Why a dedicated user rather than DynamicUser
# --------------------------------------------
# The repo's baseline is DynamicUser (CLAUDE.md rule 2), and everything else
# here follows it. It cannot apply: systemd derives a DynamicUser's UID from
# the *unit name*, so nixarchy-bbs.service and nixarchy-bbs-sync.service would
# get different UIDs, and each start would chown the shared StateDirectory away
# from the other. The sync must write the same SQLite store the server reads.
# docs/NIXOS-ANTI-PATTERNS.md permits "a dedicated user or DynamicUser"; this
# takes the first branch and keeps every other hardening knob.
#
# Exposure
# --------
# The SSH listener is deliberately public — that is the entire product. Every
# other listener the binary starts (verify/health HTTP, games WebSocket, files
# web, the loopback NNTP reader) binds 127.0.0.1 and is not reachable from
# outside the host. Reaching the public listener needs a router port-forward to
# `sshPort` and a DNS record; neither is expressible here, so both are in
# docs/applications/nixarchy-bbs.md.
{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.features.nixarchy-bbs;

  # Handles are lowercased before provisioning: GitHub allows uppercase and the
  # board's SanitizeUsername does not. Anything else it rejects (under 3 chars,
  # over 20, a reserved route name like `admin` or `msg`) makes provision-user
  # exit 1, which the sync logs and steps over.
  syncScript = pkgs.writeShellApplication {
    name = "nixarchy-bbs-sync";
    runtimeInputs = [ pkgs.gh pkgs.curl pkgs.coreutils pkgs.gnugrep ];
    text = ''
      GH_TOKEN="$(cat "$CREDENTIALS_DIRECTORY/github-token")"
      export GH_TOKEN

      granted=0
      skipped=0

      # `select(.pull_request == null)` because the issues endpoint returns PRs
      # too, and a labelled PR is not an access request.
      handles="$(gh api --paginate \
        "repos/${cfg.memberRepo}/issues?state=all&labels=${cfg.memberLabel}" \
        --jq '.[] | select(.pull_request == null) | .user.login' | sort -u)"

      if [ -z "$handles" ]; then
        echo "no issues labelled '${cfg.memberLabel}' on ${cfg.memberRepo} — nothing to provision"
        exit 0
      fi

      for handle in $handles; do
        name="$(printf '%s' "$handle" | tr '[:upper:]' '[:lower:]')"

        # Fetch first, filter second. Piping curl straight into `grep -m1`
        # would race: grep exits on the match, curl takes SIGPIPE, and
        # pipefail turns a *successful* lookup into a failure.
        if ! keys="$(curl -fsS --max-time 15 "https://github.com/$handle.keys")"; then
          echo "skip $handle: could not read https://github.com/$handle.keys"
          skipped=$((skipped + 1))
          continue
        fi

        # First published key only. The board binds one key per account, so
        # taking the top of the list leaves the choice with the member: they
        # reorder their keys on GitHub.
        key="$(printf '%s\n' "$keys" | grep -m1 -E '^(ssh|ecdsa)-' || true)"
        if [ -z "$key" ]; then
          echo "skip $handle: no usable public key published on GitHub"
          skipped=$((skipped + 1))
          continue
        fi

        # Idempotent: re-provisioning an unchanged handle+key is a no-op.
        # A member who rotates their GitHub key trips ErrKeyMismatch here and
        # stays on their old key until an operator clears it — deliberately, so
        # a compromised GitHub account cannot silently take over an account.
        if out="$(agentbbs provision-user --name "$name" --pubkey "$key" --kind member 2>&1)"; then
          granted=$((granted + 1))
        else
          echo "skip $handle: $out"
          skipped=$((skipped + 1))
        fi
      done

      echo "provisioned/confirmed $granted, skipped $skipped"
    '';
  };

  # Shared by both units. The server and the sync must agree on the data dir,
  # and the sync opens the same SQLite store (WAL, 5s busy timeout) that the
  # running server holds open.
  commonEnvironment = {
    AGENTBBS_DATA = "/var/lib/${stateDir}";
  };

  stateDir = "nixarchy-bbs";

  hardening = {
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectKernelTunables = true;
    ProtectControlGroups = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectClock = true;
    ProtectHostname = true;
    NoNewPrivileges = true;
    RestrictSUIDSGID = true;
    RestrictRealtime = true;
    RestrictNamespaces = true;
    LockPersonality = true;
    # Pure Go, no JIT and no native extensions mapping RWX — unlike the CPython
    # services in this tree, which have to leave this off.
    MemoryDenyWriteExecute = true;
    SystemCallFilter = [ "@system-service" "~@privileged" ];
    RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
  };
in
{
  options.features.nixarchy-bbs = {
    enable = lib.mkEnableOption "nixarchy-bbs — SSH bulletin board for contributors and their agents";

    hostname = lib.mkOption {
      type = lib.types.str;
      example = "bbs.example.com";
      description = ''
        Public hostname of the board. Cosmetic only — it is what the banner and
        every "reconnect with…" hint print, so getting it wrong sends members to
        the wrong address rather than breaking anything.
      '';
    };

    sshPort = lib.mkOption {
      type = lib.types.port;
      default = 2222;
      description = ''
        Port the BBS SSH server listens on, on all interfaces. This is the one
        deliberately public listener; it does not touch the host's own sshd.
        Reaching it from outside also needs a router port-forward — see
        docs/applications/nixarchy-bbs.md.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Open `sshPort` on the host firewall. Default true because a board
        nobody outside can reach is not a board. Set false to keep the service
        tailnet-only while testing.
      '';
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 8088;
      description = ''
        Loopback HTTP endpoint (`/verify`, `/healthz`, `/irc-auth`). Not
        exposed: email verification is off on this deployment, so this is a
        health probe and nothing else.
      '';
    };

    gameWsPort = lib.mkOption {
      type = lib.types.port;
      default = 8190;
      description = ''
        Loopback WebSocket endpoint for agent-vs-agent games. Upstream defaults
        to 8090, which media-bot already holds on p510 — hence the remap.
      '';
    };

    filesWebPort = lib.mkOption {
      type = lib.types.port;
      default = 8092;
      description = "Loopback web file browser for the SFTP area.";
    };

    newsPort = lib.mkOption {
      type = lib.types.port;
      default = 1119;
      description = ''
        Loopback NNTP port backing the in-hub news reader. Public NNTPS (:563)
        stays off: it needs a TLS keypair and members read news through the hub.
      '';
    };

    admins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "olafkfreund" ];
      description = ''
        Account names allowed into the `admin@` operator console. Safe to
        declare before the accounts exist — the check is by name at connect
        time, so naming a handle the sync has not provisioned yet grants
        nothing until it does.
      '';
    };

    closedRegistration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Refuse keys the board does not already know at `join@`, making a
        labelled issue on `memberRepo` the only way to get an account.

        Off by default. With it on the board is invisible to anyone not
        already approved, which is the wrong shape while it is still filling
        up; turn it on when open signup starts costing more than it brings.

        Needs the fork's AGENTBBS_CLOSED_REGISTRATION support
        (olafkfreund/nixarchy-bbs#1) — upstream has no way to close signup.
      '';
    };

    memberRepo = lib.mkOption {
      type = lib.types.str;
      example = "olafkfreund/nixarchy";
      description = ''
        `owner/repo` whose issue tracker is the membership register. Issues
        carrying `memberLabel` grant their *author* an account.
      '';
    };

    memberLabel = lib.mkOption {
      type = lib.types.str;
      default = "bbs-access";
      description = ''
        The label that grants access. Applying it is the approval, so it must be
        a label only maintainers can apply — GitHub restricts labelling to users
        with triage permission, which is exactly the property relied on here.
      '';
    };

    syncInterval = lib.mkOption {
      type = lib.types.str;
      default = "15min";
      description = ''
        `OnUnitActiveSec` between membership syncs — the delay between a
        maintainer applying the label and the account existing.
      '';
    };

    githubTokenFile = lib.mkOption {
      type = lib.types.path;
      default = config.age.secrets."api-github-token".path;
      defaultText = lib.literalExpression ''config.age.secrets."api-github-token".path'';
      description = ''
        File holding a bare GitHub token for the membership sync. Only needs to
        read issues on `memberRepo`; the token exists to lift the 60-req/hour
        unauthenticated rate limit shared by everything else on this host's IP.
      '';
    };

    signupNotify = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "you@example.com";
      description = ''
        Address the board notifies about signups. Nothing is actually sent —
        SMTP is unconfigured — but leaving this unset means the binary falls
        back to its upstream author's address, so set it to your own.
      '';
    };

    motd = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Message of the day shown atop the hub menu.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.memberRepo != "";
        message = "features.nixarchy-bbs.memberRepo must name the owner/repo whose issues grant access.";
      }
    ];

    age.secrets."api-github-token" = {
      file = ../../secrets/api-github-token.age;
      mode = "0400";
    };

    users.users.${stateDir} = {
      isSystemUser = true;
      group = stateDir;
      description = "nixarchy-bbs SSH bulletin board";
    };
    users.groups.${stateDir} = { };

    systemd.services.nixarchy-bbs = {
      description = "nixarchy-bbs — SSH bulletin board for contributors and their agents";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = commonEnvironment // {
        AGENTBBS_ADDR = ":${toString cfg.sshPort}";
        AGENTBBS_HOST = cfg.hostname;
        AGENTBBS_ADMINS = lib.concatStringsSep "," cfg.admins;

        # Only consulted on the refusal path, so setting the message
        # unconditionally is free. Both variables come from the fork's
        # feat/closed-registration change.
        AGENTBBS_CLOSED_REGISTRATION = if cfg.closedRegistration then "1" else "0";
        AGENTBBS_CLOSED_REGISTRATION_MSG =
          "This board is for ${cfg.memberRepo} contributors. "
            + "Ask for an account: open an issue at https://github.com/${cfg.memberRepo}/issues "
            + "and a maintainer will label it '${cfg.memberLabel}'. "
            + "Your account is created from the SSH keys you publish on GitHub.";

        # Not negotiable while the sync exists: provisioned members arrive with
        # no email and there is no SMTP to send a code to, so requiring
        # verification would lock out every member it just granted.
        # Self-service joiners are still asked for an email, just not blocked
        # on confirming it.
        AGENTBBS_REQUIRE_VERIFIED_EMAIL = "0";

        # The default MOTD source is upstream's own site, polled every 30
        # minutes. `motd.Start` skips an empty URL, but the caller reads it
        # through a helper that treats empty as unset and substitutes the
        # default back — so the only way to stop the poll from outside the
        # binary is to point it somewhere that fails instantly and locally.
        AGENTBBS_MOTD_URL = "http://127.0.0.1:1/motd";
        AGENTBBS_MOTD = cfg.motd;

        # Upstream's default is anthony@profullstack.com.
        AGENTBBS_SIGNUP_NOTIFY = cfg.signupNotify;

        # The sandbox wraps *external* arcade binaries (doom) in bwrap, which
        # needs the user namespaces RestrictNamespaces denies. Moot in practice:
        # AGENTBBS_ASSETS is unset so no external binary exists, and the Go
        # games (snake, hangman) run in-process either way.
        AGENTBBS_SANDBOX = "none";

        # Gopher wants :70 and public NNTPS wants :563 — both privileged, and
        # neither worth an AmbientCapability. News still works: the hub reader
        # talks to the loopback NNTP port below.
        AGENTBBS_GOPHER = "0";

        AGENTBBS_HTTP_ADDR = "127.0.0.1:${toString cfg.httpPort}";
        AGENTBBS_GAME_WS_ADDR = "127.0.0.1:${toString cfg.gameWsPort}";
        AGENTBBS_FILES_WEB_ADDR = "127.0.0.1:${toString cfg.filesWebPort}";
        AGENTBBS_NEWS_ADDR = "127.0.0.1:${toString cfg.newsPort}";
      };

      serviceConfig = hardening // {
        ExecStart = lib.getExe pkgs.customPkgs.nixarchy-bbs;
        User = stateDir;
        Group = stateDir;
        StateDirectory = stateDir;
        StateDirectoryMode = "0700";
        Restart = "on-failure";
        RestartSec = 5;
        MemoryMax = "1G";
        TasksMax = 256;
      };
    };

    # Membership sync. Writes the same SQLite store the server holds open,
    # which is safe: the store opens WAL with a 5s busy timeout.
    systemd.services.nixarchy-bbs-sync = {
      description = "Provision nixarchy-bbs members from labelled GitHub issues";
      after = [ "network-online.target" "nixarchy-bbs.service" ];
      wants = [ "network-online.target" ];

      path = [ pkgs.customPkgs.nixarchy-bbs ];
      environment = commonEnvironment;

      serviceConfig = hardening // {
        Type = "oneshot";
        ExecStart = lib.getExe syncScript;
        User = stateDir;
        Group = stateDir;
        StateDirectory = stateDir;
        StateDirectoryMode = "0700";
        # agenix decrypts the token root-owned at 0400; systemd copies it into
        # the unit's credential directory where the service user can read it.
        LoadCredential = [ "github-token:${cfg.githubTokenFile}" ];
      };
    };

    systemd.timers.nixarchy-bbs-sync = {
      description = "Periodic nixarchy-bbs membership sync from GitHub";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = cfg.syncInterval;
        Unit = "nixarchy-bbs-sync.service";
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.sshPort ];
  };
}
