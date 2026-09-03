# Matrix homeserver — the substrate under the agent bus.
#
# The store behind modules/services/agent-bus-mcp.nix. Agents reach it through
# four MCP tools; humans reach the same rooms with any Matrix client. That is
# the whole point of choosing a real chat server over a bespoke message table:
# one store, two faces. The BBS this replaces had three stores that could not
# see each other (inbox, news, IRC), which is why nothing could follow a
# conversation across them.
#
# continuwuity rather than conduwuit: conduwuit was removed from nixpkgs after
# upstream deleted the repository, and `services.conduwuit` survives only as a
# removed-option stub that errors on eval. continuwuity is the maintained
# continuation and is config-compatible. `matrix-tuwunel` is the other
# successor; either would do.
#
# Federation is OFF. We want accounts on this server talking to each other, not
# to matrix.org. The client-server API is fully functional without it, and
# turning it off removes the whole /.well-known/matrix/server and port-8448
# surface along with any inbound federation traffic.
{ config
, lib
, ...
}:
let
  cfg = config.features.matrix-continuwuity;
in
{
  options.features.matrix-continuwuity = {
    enable = lib.mkEnableOption "Matrix homeserver (continuwuity) backing the agent bus";

    serverName = lib.mkOption {
      type = lib.types.str;
      example = "example.com";
      description = ''
        The identity suffix in `@user:<serverName>` and in every room id.

        **Permanent.** Changing it later means wiping the database, because
        every id already minted embeds it. It does not have to resolve to this
        machine and is not the hostname clients connect to — that is
        `publicUrl` below, advertised through `/.well-known/matrix/client`.
      '';
    };

    publicUrl = lib.mkOption {
      type = lib.types.str;
      example = "https://matrix.example.com";
      description = ''
        Where clients actually reach the homeserver, advertised as
        `well_known.client`. This is the tunnel hostname, not `serverName`.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 6167;
      description = ''
        Loopback port. Never exposed directly: the Cloudflare tunnel proxies
        `/_matrix/` to it over HTTPS, which is the tunnel doing the job it is
        actually for — unlike SSH, which it cannot carry.
      '';
    };

    registrationTokenFile = lib.mkOption {
      type = lib.types.path;
      default = config.age.secrets."matrix-registration-token".path;
      defaultText = lib.literalExpression ''config.age.secrets."matrix-registration-token".path'';
      description = ''
        Token gating account creation. Registration is open but token-gated:
        continuwuity has no Synapse-style HTTP admin API, so a token is the
        only scriptable way to provision accounts — user administration
        otherwise happens through commands in an in-Matrix admin room.

        Anyone holding this can create an account. Rotate it once the agents
        exist, or set `allowRegistration = false` and rotate nothing.
      '';
    };

    allowRegistration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether new accounts can be created with the registration token. Turn
        this off once every agent and person that needs an account has one; the
        server keeps working and nobody new can appear.
      '';
    };
  };

  # No `age.secrets."matrix-registration-token"` here on purpose. It is declared
  # once in modules/secrets/api-keys.nix, which every host imports, because the
  # workstations need the same token to register their per-session identities.
  # Redeclaring it would be an option conflict -- and one that a toplevel build
  # does not force, so it would pass locally and fail CI (see #1634).
  config = lib.mkIf cfg.enable {
    services.matrix-continuwuity = {
      enable = true;
      settings.global = {
        server_name = cfg.serverName;
        port = [ cfg.port ];

        allow_federation = false;
        allow_encryption = true;

        allow_registration = cfg.allowRegistration;
        registration_token_file = cfg.registrationTokenFile;

        # Off by default it phones continuwuity.org for announcements on a
        # timer. Nothing here needs that.
        allow_announcements_check = false;

        # Upstream appends a transgender flag emoji to every new display name.
        # Fine as an upstream default, noise on a board full of `agent-*`.
        new_user_displayname_suffix = "";

        # Only consulted for federation, which is off.
        trusted_servers = [ ];

        well_known.client = cfg.publicUrl;
      };
    };

    # `database_path` is readOnly in the upstream module — forced to
    # /var/lib/continuwuity via StateDirectory, and setting it fails
    # evaluation. Worth knowing on this host, where / is tight; a homeserver
    # for a handful of agents is megabytes, so it fits, but it is not
    # relocatable without changing where /var/lib lives.
  };
}
