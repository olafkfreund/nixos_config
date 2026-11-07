# Gate for #2758: with trusted-users = [ "root" ] and require-sigs = true,
# remote builds and copies still work when paths are signed, and fail when not.
{ pkgs }:
let
  keys = import "${pkgs.path}/nixos/tests/ssh-keys.nix" pkgs;

  # Input-addressed, unique per name; `dep` becomes an input source of the derivation.
  tNix = pkgs.writeText "t.nix" ''
    { name, dep ? null }:
    let d = if dep == null then "" else "''${builtins.storePath dep}";
    in derivation {
      inherit name;
      system = "x86_64-linux";
      builder = "/bin/sh";
      args = [ "-c" "echo ''${name} ''${d} > $out" ];
    }
  '';

  node = { ... }: {
    services.openssh.enable = true;
    users.users.alice = {
      isNormalUser = true;
      openssh.authorizedKeys.keys = [ keys.snakeOilEd25519PublicKey ];
    };
    environment.etc."t.nix".source = tNix;
    environment.etc."alice-key" = {
      source = keys.snakeOilEd25519PrivateKey;
      user = "alice";
      mode = "0600";
    };
    programs.ssh.extraConfig = ''
      Host *
        User alice
        IdentityFile /etc/alice-key
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
    '';
    nix.checkConfig = false;
    nix.extraOptions = "!include /etc/nix/test-keys.conf";
    nix.settings = {
      trusted-users = [ "root" ];
      require-sigs = true;
      substituters = pkgs.lib.mkForce [ ];
      sandbox = false;
      experimental-features = [ "nix-command" "flakes" ];
      secret-key-files = "/var/lib/nix-key";
    };
  };
in
pkgs.testers.runNixOSTest {
  name = "nix-untrusted-remote-build";
  nodes = {
    builder = node;
    client = node;
    stranger = node;
  };
  testScript = ''
    import shlex

    SIG = "lacks a signature by a trusted key"

    def alice(m, cmd):
        return m.succeed("runuser -l alice -c " + shlex.quote(cmd + " 2>&1")).strip()

    def alice_fails(m, cmd, needle=None):
        status, out = m.execute("runuser -l alice -c " + shlex.quote(cmd + " 2>&1"))
        assert status != 0, f"expected failure: {cmd}\n{out}"
        if needle:
            assert needle in out, f"missing '{needle}' in: {out}"

    def last(s):
        return s.splitlines()[-1]

    start_all()
    for m in (builder, client, stranger):
        m.wait_for_unit("sshd.service")

    # Each node signs with its own key; peers trust by public key.
    pub = {}
    for m, n in ((builder, "builder"), (client, "client"), (stranger, "stranger")):
        m.succeed(f"umask 077; nix key generate-secret --key-name {n}-1 > /var/lib/nix-key")
        pub[n] = m.succeed("nix key convert-secret-to-public < /var/lib/nix-key").strip()
    for m, peers in ((builder, ["client"]), (client, ["builder"]), (stranger, [])):
        conf = "".join(f"extra-trusted-public-keys = {pub[p]}\n" for p in peers)
        m.succeed(f"printf %s {shlex.quote(conf)} > /etc/nix/test-keys.conf")
        m.succeed("systemctl restart nix-daemon.service")

    with subtest("1: alice is untrusted everywhere"):
        for m in (builder, client, stranger):
            assert "Trusted: 0" in alice(m, "nix store info"), "local store trusted"
        for n in ("builder", "stranger"):
            assert "Trusted: 0" in alice(client, f"nix store info --store ssh-ng://{n}")

    with subtest("2: unsigned closure refused, signed closure accepted"):
        u = last(client.succeed("nix-build /etc/t.nix --option secret-key-files ''' --argstr name u-unsigned --no-out-link"))
        assert "client-1:" not in client.succeed(f"nix path-info --sigs {u}")
        d = client.succeed(f"nix-instantiate /etc/t.nix --argstr name d-dep --argstr dep {u}").strip()
        for p in (u, d):
            builder.fail(f"nix path-info {p}")
        alice_fails(client, f"nix-copy-closure --to builder {d}", SIG)
        client.succeed(f"nix store sign -r --key-file /var/lib/nix-key {d}")
        alice(client, f"nix-copy-closure --to builder {d}")
        builder.succeed(f"nix path-info {d}")

    with subtest("3: builder builds the uploaded drv and signs the output"):
        out = client.succeed(f"nix-store -q --outputs {d}").strip()
        client.fail(f"nix path-info {out}")
        builder.fail(f"nix path-info {out}")
        alice(client, f"ssh builder nix build --no-link '{d}^*'")
        assert "builder-1:" in alice(client, f"ssh builder nix path-info --sigs {out}")

    with subtest("4: copy the output back"):
        alice(client, f"nix-copy-closure --from builder {out}")
        client.succeed(f"nix path-info {out}")

    with subtest("5: nix copy of a client-built path to builder"):
        p5 = last(alice(client, "nix-build /etc/t.nix --argstr name c-built --no-out-link"))
        builder.fail(f"nix path-info {p5}")
        alice(client, f"nix copy --to ssh-ng://builder {p5}")
        builder.succeed(f"nix path-info {p5}")

    with subtest("6: stranger refuses a path signed by an unknown key"):
        p6 = last(alice(client, "ssh builder nix-build /etc/t.nix --argstr name b-built --no-out-link"))
        stranger.fail(f"nix path-info {p6}")
        alice_fails(client, f"nix copy --from ssh-ng://builder --to ssh-ng://stranger {p6}", SIG)
  '';
}
