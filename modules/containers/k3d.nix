# k3d (k3s in Docker) cluster bootstrap.
#
# Runs a single-node k3s cluster inside the host Docker daemon. The cluster
# is created on first boot by a one-shot systemd unit and persisted via
# Docker volumes (under the host's Docker data-root). Local-path PV storage
# is bind-mounted to ${cfg.storageDir} so PVCs survive cluster recreation
# AND don't pressure /mnt/media.
#
# After the cluster exists this unit also applies a GitOps bootstrap
# (kubectl apply -k <cfg.argocd.gitopsRepo>/<cfg.argocd.bootstrapPath>),
# which is expected to install ArgoCD plus the App-of-Apps root
# Application. ArgoCD then self-manages everything else.
#
# Tailnet exposure model — SIDECAR pattern:
#
# Each Pod that should be reachable on the tailnet runs an in-pod
# `tailscale` sidecar container alongside its main container(s). The
# sidecar registers a new tailnet node (e.g. `argocd.tail833f7.ts.net`)
# using a reusable auth key materialised by the bootstrap unit at
# `tailscale/auth-key` (key `TS_AUTHKEY`) inside the cluster.
#
# We chose sidecars over the Tailscale Kubernetes Operator because the
# operator requires OAuth client credentials (admin → OAuth clients) and
# this homelab is wired with a plain auth key (admin → Keys). Sidecar
# trade-offs vs operator:
#   + works with an auth key
#   + no CRDs, no extra control-plane component
#   - more boilerplate per service (sidecar container + 2 env refs)
#   - auth-key rotation is manual (Tailscale max key TTL is 90 days,
#     reusable keys can be longer if configured). When the key in agenix
#     is replaced (manage-secrets.sh edit), restart the bootstrap unit
#     to refresh the in-cluster Secret, then bounce any sidecar-running
#     Pods so they re-register.
#
# Why this won't clash with the host-level `tailscale serve` setup on
# p510: the host's `tailscaled` and `tailscale serve` config bind port
# 443 on the p510 tailnet node only. Sidecars register entirely separate
# tailnet nodes from inside the cluster — completely independent.
#
# This module is opt-in per host — import ../../modules/containers/k3d.nix
# in the host's configuration.nix imports list, then flip
# modules.containers.k3d.enable = true.

{ config
, lib
, pkgs
, hostUsers ? [ ]
, ...
}:
let
  inherit (lib) mkOption mkIf mkMerge mkEnableOption mkPackageOption types optionalString concatStringsSep;
  cfg = config.modules.containers.k3d;

  # Bootstrap script — idempotent. Safe to re-run; safe to fail partially
  # and re-run (each step uses `kubectl apply` or `k3d cluster list` checks).
  bootstrapScript = pkgs.writeShellApplication {
    name = "k3d-cluster-bootstrap";
    runtimeInputs = with pkgs; [
      cfg.package
      kubectl
      kubernetes-helm
      jq
      coreutils
      docker-client
      # `ip` (iproute2) — the reboot path waits for the API bind IP to appear
      # on an interface before (re)starting the cluster.
      iproute2
      # `kubectl apply -k` against a remote git URL shells out to `git`.
      # Without this, the bootstrap fails the GitOps step with
      # "no 'git' program on path: exec: \"git\": executable file not
      # found in $PATH" — observed in first deploy.
      git
    ];
    text = ''
      set -euo pipefail
      umask 077

      CLUSTER="${cfg.clusterName}"
      KUBECONFIG_OUT="${cfg.kubeconfigPath}"
      API_PORT="${toString cfg.apiPort}"
      API_BIND="${cfg.apiHostBind}"
      STORAGE_DIR="${cfg.storageDir}"

      mkdir -p "$(dirname "$KUBECONFIG_OUT")" "$STORAGE_DIR"

      # Host-side API reachability check: pulls a fresh kubeconfig (which points
      # at ${cfg.apiHostBind}:$API_PORT — i.e. the serverlb's PUBLISHED host
      # port) and hits /readyz. This verifies the port-publish actually works
      # from the host, not just that the in-container API is up.
      api_reachable() {
        k3d kubeconfig get "$CLUSTER" > /tmp/k3d-bootstrap-healthcheck 2>/dev/null || return 1
        KUBECONFIG=/tmp/k3d-bootstrap-healthcheck kubectl get --raw=/readyz >/dev/null 2>&1
      }

      # The API binds to ${cfg.apiHostBind}. On a host reboot that interface
      # (e.g. tailscale0) can come up AFTER docker, so wait for the address to
      # exist before (re)starting the cluster — otherwise the serverlb fails to
      # publish the port. Skip for wildcard/loopback binds.
      case "$API_BIND" in
        0.0.0.0 | 127.0.0.1) ;;
        *)
          for i in $(seq 1 30); do
            ip -o addr show 2>/dev/null | grep -qw "$API_BIND" && break
            echo "[k3d-bootstrap] waiting for API bind IP $API_BIND ($i/30)…"
            sleep 2
          done
          ;;
      esac

      # 1. Create cluster if missing
      if ! k3d cluster list -o json | jq -e --arg n "$CLUSTER" '.[] | select(.name==$n)' >/dev/null; then
        echo "[k3d-bootstrap] Creating cluster $CLUSTER (api ${cfg.apiHostBind}:$API_PORT, storage $STORAGE_DIR)"
        k3d cluster create "$CLUSTER" \
          --image "${cfg.k3sImage}" \
          --api-port "${cfg.apiHostBind}:$API_PORT" \
          --servers 1 \
          --agents 0 \
          --k3s-arg "--disable=traefik@server:*" \
          --k3s-arg "--disable=servicelb@server:*" \
          --volume "$STORAGE_DIR:/var/lib/rancher/k3s/storage@server:*" \
          --wait
      else
        echo "[k3d-bootstrap] Cluster $CLUSTER already exists (reboot path); ensuring API reachable"
        k3d cluster start "$CLUSTER" >/dev/null 2>&1 || true

        # Self-heal the serverlb port-publish race. After a reboot Docker's
        # restart-policy can resurrect the serverlb before the bind interface is
        # up, so its host port silently never publishes and `k3d cluster start`
        # no-ops on the "already running" containers — API unreachable from the
        # host. Fix with a clean, NON-DESTRUCTIVE stop/start cycle (re-creates
        # the LB's port mapping). No delete: PVCs, etcd and the Keycloak realm
        # are all preserved.
        healed=0
        for attempt in $(seq 1 5); do
          for i in $(seq 1 15); do api_reachable && break; sleep 2; done
          if api_reachable; then
            [ "$attempt" -gt 1 ] && echo "[k3d-bootstrap] API reachable after self-heal (attempt $attempt)"
            healed=1; break
          fi
          echo "[k3d-bootstrap] host API $API_BIND:$API_PORT unreachable — clean stop/start (attempt $attempt/5)"
          k3d cluster stop "$CLUSTER" >/dev/null 2>&1 || true
          docker rm -f "k3d-$CLUSTER-tools" >/dev/null 2>&1 || true
          k3d cluster start "$CLUSTER" >/dev/null 2>&1 || true
        done
        if [ "$healed" != 1 ]; then
          echo "[k3d-bootstrap] WARNING: host API still unreachable after 5 self-heal cycles" >&2
        fi
      fi

      # 2. Materialise host-side kubeconfig
      echo "[k3d-bootstrap] Writing kubeconfig to $KUBECONFIG_OUT"
      k3d kubeconfig get "$CLUSTER" > "$KUBECONFIG_OUT".tmp
      mv "$KUBECONFIG_OUT".tmp "$KUBECONFIG_OUT"
      chgrp wheel "$KUBECONFIG_OUT"
      chmod 0640 "$KUBECONFIG_OUT"

      export KUBECONFIG="$KUBECONFIG_OUT"

      # 3. Wait for kube API to be ready (k3d --wait covers server start,
      #    but the kube API can take an extra moment to accept requests)
      for i in $(seq 1 30); do
        if kubectl get nodes >/dev/null 2>&1; then break; fi
        echo "[k3d-bootstrap] Waiting for kube API ($i/30)…"
        sleep 2
      done
      kubectl get nodes

      ${optionalString cfg.tailscaleAuthKey.enable ''
      # 4. Seed the Tailscale auth-key Secret for sidecar consumption.
      #    Sidecar containers mount this Secret as TS_AUTHKEY (the env
      #    var the `tailscale/tailscale` image reads to join the tailnet
      #    non-interactively).
      kubectl create namespace tailscale --dry-run=client -o yaml | kubectl apply -f -

      if [ -r "${cfg.tailscaleAuthKey.authKeyFile}" ]; then
        # Read raw token (single-line file, no JSON wrapping)
        TS_AUTHKEY=$(tr -d '\n\r ' < "${cfg.tailscaleAuthKey.authKeyFile}")
        kubectl -n tailscale create secret generic auth-key \
          --from-literal=TS_AUTHKEY="$TS_AUTHKEY" \
          --dry-run=client -o yaml | kubectl apply -f -
        echo "[k3d-bootstrap] Seeded tailscale/auth-key from agenix"
        # Also project to namespaces that consume it (argocd, factory).
        # Reflector or external-secrets would be cleaner long-term, but
        # one-shot copy keeps the bootstrap self-contained.
        for ns in argocd factory; do
          kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
          kubectl -n "$ns" create secret generic tailscale-auth-key \
            --from-literal=TS_AUTHKEY="$TS_AUTHKEY" \
            --dry-run=client -o yaml | kubectl apply -f -
        done
      else
        echo "[k3d-bootstrap] WARN: ${cfg.tailscaleAuthKey.authKeyFile} not readable yet;" \
             "create the agenix secret, then: systemctl restart k3d-cluster-bootstrap"
      fi
      ''}

      ${optionalString cfg.factorySecrets.enable ''
      # 4b. Seed all factory-namespace Secret manifests from agenix.
      #     Each .age file decrypts to a full kubectl-applicable Secret
      #     YAML (`apiVersion: v1, kind: Secret, metadata.namespace:
      #     factory, data: …`). kubectl apply -f is idempotent: when the
      #     decrypted content matches the live Secret's content, this is
      #     a no-op; when it differs (e.g. after rotation via
      #     `./scripts/manage-secrets.sh edit factory-secret-<name>`),
      #     the new value takes effect on the next bootstrap restart.
      #     See #807 for design rationale.
      kubectl create namespace factory --dry-run=client -o yaml | kubectl apply -f -
      for slot in \
        ${concatStringsSep " " (map (n: "factory-secret-${n}") [
          "cloudflared-factory"
          "factory-secrets"
          "factory-cli-creds"
          "ghcr-pull"
          "skillai-db"
          "skillai-app"
          "rolehunter-db"
          "rolehunter-app"
          "factory-db-aifactory"
          "factory-db-pfactory"
          "factory-db-tfactory"
          "minio-creds"
          "oauth2-proxy-cfactory"
          "oauth2-proxy-observe"
          "oauth2-proxy-odin"
          "observe-root"
          "otel-otlp-auth"
          "cfactory-api-keys"
          "odin-ssh-key"
        ])} \
      ; do
        f="/run/agenix/$slot"
        if [ -r "$f" ]; then
          # -n factory pins the target namespace; the extracted Secret
          # manifests have metadata.namespace stripped (yq during
          # extraction), so without this flag kubectl would default to
          # whichever namespace the kubeconfig has set (`default`),
          # silently creating duplicates outside factory.
          kubectl apply -n factory -f "$f" >/dev/null \
            && echo "[k3d-bootstrap] Applied factory/$slot from agenix" \
            || echo "[k3d-bootstrap] WARN: apply of $slot failed (continuing)"
        else
          echo "[k3d-bootstrap] WARN: $f not readable; skipping $slot." \
               "Run: ./scripts/manage-secrets.sh edit $slot"
        fi
      done
      ''}

      ${optionalString cfg.argocd.enable ''
      # 5. Apply the GitOps bootstrap. Expected to install ArgoCD + the
      #    App-of-Apps root Application from ${cfg.argocd.gitopsRepo}.
      #    Idempotent: re-applies cleanly if anything drifts.
      BOOTSTRAP_URL="${cfg.argocd.gitopsRepo}//${cfg.argocd.bootstrapPath}?ref=${cfg.argocd.gitopsRef}"
      echo "[k3d-bootstrap] Applying $BOOTSTRAP_URL"
      if ! kubectl apply -k "$BOOTSTRAP_URL"; then
        echo "[k3d-bootstrap] WARN: kustomize apply failed (repo may not exist yet)." \
             "Once ${cfg.argocd.gitopsRepo} has the bootstrap/ kustomization," \
             "re-run: systemctl restart k3d-cluster-bootstrap"
      fi
      ''}

      echo "[k3d-bootstrap] Done."
    '';
  };
in
{
  options.modules.containers.k3d = {
    enable = mkEnableOption "k3d (k3s in Docker) cluster bootstrap";

    package = mkPackageOption pkgs "k3d" { };

    k3sImage = mkOption {
      type = types.str;
      default = "rancher/k3s:v1.31.5-k3s1";
      description = ''
        k3s node image k3d boots the cluster from (passed to
        `k3d cluster create --image`).

        Pin this explicitly rather than relying on the k3d binary's
        built-in default: that default was an ancient `v1.21.7-k3s1`
        whose bundled containerd/runc mishandles shared-memory page
        faults on modern host kernels, making every PostgreSQL pod die
        during `initdb` with `Bus error (core dumped)`. A current k3s
        ships a runc that handles this correctly.

        NOTE: this only takes effect on cluster *creation*. To adopt a
        new image on an existing cluster, delete and recreate it:
        `k3d cluster delete ${"$"}{clusterName}` then re-run the
        bootstrap unit (`systemctl start k3d-cluster-bootstrap`).
      '';
    };

    clusterName = mkOption {
      type = types.str;
      default = "factory";
      description = "Name of the k3d cluster (used as the docker container prefix and config selector).";
    };

    apiPort = mkOption {
      type = types.port;
      default = 6443;
      description = ''
        Host port for the kube API server. Use `kubectl --kubeconfig
        ${"$"}{kubeconfigPath}` from the host, or set `apiHostBind` to
        a non-loopback address to reach it from elsewhere.
      '';
    };

    apiHostBind = mkOption {
      type = types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = ''
        Host IP the kube API server binds to.

        Defaults to `127.0.0.1` — loopback only, requires SSH tunnel /
        port-forward for off-host kubectl. Set to `0.0.0.0` (or a
        specific interface IP) to expose the API to the LAN/tailnet so
        kubectl can connect directly. With a default-open Tailscale
        ACL and a disabled host firewall, `0.0.0.0` and `127.0.0.1`
        are equivalent reachability-wise — the API is gated by the
        bearer token in the kubeconfig regardless.
      '';
    };

    storageDir = mkOption {
      type = types.path;
      default = "/mnt/img_pool/k3d/storage";
      description = ''
        Host directory bind-mounted into the k3d server container at
        /var/lib/rancher/k3s/storage. Used as the backing store for the
        local-path-provisioner (the default StorageClass shipped with k3s).
        Keep this off /mnt/media so cluster PVCs don't compete with the
        media library for IOPS.
      '';
    };

    kubeconfigPath = mkOption {
      type = types.path;
      default = "/etc/k3d/kubeconfig";
      description = ''
        Where to write the host-side kubeconfig. Mode 0640, group wheel —
        any user in the wheel group can read it. Set KUBECONFIG to this
        path in your shell to drive the cluster.
      '';
    };

    users = mkOption {
      type = types.listOf types.str;
      default = hostUsers;
      example = [ "olafkfreund" ];
      description = ''
        Users whose login shell will export KUBECONFIG=${"$"}{kubeconfigPath}.
        These users must already be in the wheel group to actually read
        the file — this option just sets the env var.
      '';
    };

    argocd = {
      enable = mkEnableOption "Apply the GitOps bootstrap (kubectl apply -k <gitopsRepo>/<bootstrapPath>) after cluster create";

      gitopsRepo = mkOption {
        type = types.str;
        default = "https://github.com/olafkfreund/factory-gitops";
        description = ''
          Git repo URL holding the bootstrap kustomization (App-of-Apps
          root). Expected to contain a `bootstrap/` directory with a
          kustomization.yaml that installs ArgoCD + the root Application.
        '';
      };

      gitopsRef = mkOption {
        type = types.str;
        default = "main";
        description = "Branch or tag to pin the bootstrap apply against.";
      };

      bootstrapPath = mkOption {
        type = types.str;
        default = "bootstrap";
        description = "Path inside the gitops repo containing the kustomization to apply.";
      };
    };

    tailscaleAuthKey = {
      enable = mkEnableOption "Materialise the Tailscale auth-key Secret in the cluster (for sidecar consumption)";

      authKeyFile = mkOption {
        type = types.path;
        default = config.age.secrets.tailscale-k8s-operator-oauth.path or "/run/agenix/tailscale-k8s-operator-oauth";
        defaultText = lib.literalExpression ''config.age.secrets.tailscale-k8s-operator-oauth.path'';
        description = ''
          Path to the agenix-decrypted file containing the Tailscale auth
          key. Expected shape: a single-line tskey-auth-… token, no
          surrounding JSON.

          Generate at https://login.tailscale.com/admin/settings/keys →
          "Generate auth key" with: Reusable, Ephemeral=false (so
          sidecar-registered nodes persist across pod restarts), Expiry
          90d. Then:
            ./scripts/manage-secrets.sh edit tailscale-k8s-operator-oauth
          and paste the raw token (the agenix slot name is kept as
          *-operator-oauth for backwards-compatibility with existing
          deploys; the value is just the token).
        '';
      };

      targetNamespaces = mkOption {
        type = types.listOf types.str;
        default = [ "argocd" "factory" ];
        description = ''
          Namespaces (in addition to `tailscale`) that get a copy of the
          auth-key Secret as `tailscale-auth-key`. Add any namespace that
          will run Tailscale sidecars. The namespace is auto-created if
          missing.
        '';
      };
    };

    # ── Factory app secrets (#807) ───────────────────────────────────────
    # Each agenix `factory-secret-<name>.age` file contains a complete
    # kubectl-applicable Secret manifest for the `factory` namespace. The
    # bootstrap unit `kubectl apply -f`s each one on every run so a fresh
    # cluster (or one rebuilt from scratch) gets SkillAI / rolehunter /
    # shared factory-secrets durably restored from declarative source
    # rather than out-of-band `kubectl create secret` commands.
    #
    # All 8 secrets are seeded as a single block (no per-secret enable);
    # add or remove from the `apply each one` loop below to evolve scope.
    factorySecrets = {
      enable = mkEnableOption "Apply all factory-namespace agenix-encrypted Secret manifests during cluster bootstrap";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.modules.containers.docker.enable;
        message = "modules.containers.k3d requires modules.containers.docker.enable = true (k3d needs the host Docker daemon).";
      }
    ];

    environment.systemPackages = with pkgs; [
      cfg.package
      kubectl
      kubernetes-helm
      kustomize
      k9s
      argocd
    ];

    # /etc/k3d (root:wheel 0750) so wheel members can read the kubeconfig
    # but not edit it; /mnt/img_pool/k3d/storage for PV state.
    systemd.tmpfiles.rules = [
      "d /etc/k3d 0750 root wheel - -"
      "d ${cfg.storageDir} 0755 root root - -"
    ];

    systemd.services.k3d-cluster-bootstrap = {
      description = "k3d cluster bootstrap (create cluster, write kubeconfig, apply GitOps)";
      wantedBy = [ "multi-user.target" ];
      after = [ "docker.service" "network-online.target" "tailscaled.service" ];
      requires = [ "docker.service" ];
      wants = [ "network-online.target" "tailscaled.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${bootstrapScript}/bin/k3d-cluster-bootstrap";
        # Bootstrap script needs network egress (pull k3s + bootstrap repo)
        # and docker socket access — run as root, not DynamicUser. The
        # cluster workloads themselves run inside k3d containers, not as
        # this unit.
        User = "root";
        # Re-run on transient failure (e.g. docker daemon not ready yet)
        Restart = "on-failure";
        RestartSec = "10s";
      };

      environment = {
        KUBECONFIG = cfg.kubeconfigPath;
        # Make sure docker.sock is reachable
        DOCKER_HOST = "unix:///var/run/docker.sock";
      };
    };

    # Keycloak realm backup. The realm/clients/users live in an H2 database on
    # the keycloak-data PVC. A full cluster recreate gives that PVC a fresh
    # empty directory (realm lost — incident 2026-06-25, recovered only because
    # the previous H2 happened to linger orphaned on disk). This timer copies
    # the live H2 to durable, stable storage so a recovery point always exists,
    # independent of the churning per-recreate PVC directory.
    systemd.services.keycloak-realm-backup = mkIf cfg.argocd.enable {
      description = "Backup Keycloak realm (H2 database) to durable storage";
      after = [ "k3d-cluster-bootstrap.service" ];
      path = with pkgs; [ kubectl jq coreutils ];
      environment.KUBECONFIG = cfg.kubeconfigPath;
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "keycloak-realm-backup" ''
          set -uo pipefail
          BACKUP_DIR="${builtins.dirOf (toString cfg.storageDir)}/backups/keycloak"
          mkdir -p "$BACKUP_DIR"
          vol=$(kubectl get pvc keycloak-data -n factory -o jsonpath='{.spec.volumeName}' 2>/dev/null) || exit 0
          [ -n "$vol" ] || { echo "[keycloak-backup] no keycloak-data PVC yet; skipping" >&2; exit 0; }
          pvpath=$(kubectl get pv "$vol" -o jsonpath='{.spec.hostPath.path}{.spec.local.path}' 2>/dev/null)
          # The PV path is the IN-k3d-NODE path (/var/lib/rancher/k3s/storage/<dir>).
          # The matching HOST path is ${toString cfg.storageDir}/<dir>, since that
          # directory is bind-mounted into the k3d server node.
          h2="${toString cfg.storageDir}/$(basename "$pvpath")/h2/keycloakdb.mv.db"
          if [ -f "$h2" ]; then
            ts=$(date +%Y%m%d-%H%M%S)
            cp -f "$h2" "$BACKUP_DIR/keycloakdb-$ts.mv.db"
            cp -f "$h2" "$BACKUP_DIR/keycloakdb-latest.mv.db"
            # keep the 14 most recent timestamped backups
            ls -1t "$BACKUP_DIR"/keycloakdb-2*.mv.db 2>/dev/null | tail -n +15 | xargs -r rm -f
            echo "[keycloak-backup] saved -> $BACKUP_DIR/keycloakdb-$ts.mv.db ($(wc -c < "$h2") bytes)"
          else
            echo "[keycloak-backup] H2 not found at $h2 (keycloak may be mid-start); skipping" >&2
          fi
        '';
      };
    };

    systemd.timers.keycloak-realm-backup = mkIf cfg.argocd.enable {
      description = "Periodic Keycloak realm backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };

    # skillai application database backup. skillai-db is a PostgreSQL
    # StatefulSet on a dynamic local-path PVC; a full cluster recreate
    # re-points it at a fresh empty PVC and the data is lost (incident
    # 2026-06-25, recovered only because the previous PVC dir lingered
    # orphaned on disk). Unlike Keycloak's raw H2 copy, a logical pg_dump
    # (-Fc custom format) is consistent and version-independent — restore
    # with `pg_restore -U skillai -d skillai --clean --if-exists`.
    systemd.services.skillai-db-backup = mkIf cfg.argocd.enable {
      description = "Backup skillai PostgreSQL database (pg_dump) to durable storage";
      after = [ "k3d-cluster-bootstrap.service" ];
      path = with pkgs; [ kubectl coreutils ];
      environment.KUBECONFIG = cfg.kubeconfigPath;
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "skillai-db-backup" ''
          set -uo pipefail
          BACKUP_DIR="${builtins.dirOf (toString cfg.storageDir)}/backups/skillai"
          mkdir -p "$BACKUP_DIR"
          # Only dump when the DB pod is actually Running; skip cleanly
          # otherwise (mid-start, scaled down, cluster not up yet).
          phase=$(kubectl get pod skillai-db-0 -n factory -o jsonpath='{.status.phase}' 2>/dev/null) || exit 0
          [ "$phase" = "Running" ] || { echo "[skillai-backup] skillai-db-0 not Running ($phase); skipping" >&2; exit 0; }
          ts=$(date +%Y%m%d-%H%M%S)
          out="$BACKUP_DIR/skillai-$ts.dump"
          # -Fc emits binary; no TTY (-t) so the stream stays clean.
          if kubectl exec -n factory skillai-db-0 -- pg_dump -U skillai -d skillai -Fc > "$out" 2>/dev/null && [ -s "$out" ]; then
            cp -f "$out" "$BACKUP_DIR/skillai-latest.dump"
            # keep the 14 most recent timestamped dumps
            ls -1t "$BACKUP_DIR"/skillai-2*.dump 2>/dev/null | tail -n +15 | xargs -r rm -f
            echo "[skillai-backup] saved -> $out ($(wc -c < "$out") bytes)"
          else
            rm -f "$out"
            echo "[skillai-backup] pg_dump failed (db mid-start?); skipping" >&2
            exit 0
          fi
        '';
      };
    };

    systemd.timers.skillai-db-backup = mkIf cfg.argocd.enable {
      description = "Periodic skillai database backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };

    # Make `kubectl` Just Work for wheel users without manual KUBECONFIG
    # exports. This is a host-wide env var; harmless when the file doesn't
    # exist yet (kubectl errors clearly), and Just Right once the bootstrap
    # has run.
    environment.variables.KUBECONFIG = cfg.kubeconfigPath;

    # Self-declare the Tailscale auth-key agenix secret so callers don't
    # have to manage it host-side. The filename keeps its historical
    # `-operator-oauth` suffix to avoid breaking existing secrets.nix
    # entries; the *contents* are now a raw auth key, not OAuth JSON.
    age.secrets = mkMerge [
      (mkIf cfg.tailscaleAuthKey.enable {
        tailscale-k8s-operator-oauth = {
          file = ../../secrets/tailscale-k8s-operator-oauth.age;
          mode = "0400";
          owner = "root";
          group = "root";
        };
      })
      (mkIf cfg.factorySecrets.enable (
        let
          mkSecret = n: {
            name = "factory-secret-${n}";
            value = {
              file = ../../secrets/factory-secret-${n}.age;
              mode = "0400";
              owner = "root";
              group = "root";
            };
          };
        in
        builtins.listToAttrs (map mkSecret [
          "cloudflared-factory"
          "factory-secrets"
          "factory-cli-creds"
          "ghcr-pull"
          "skillai-db"
          "skillai-app"
          "rolehunter-db"
          "rolehunter-app"
          "factory-db-aifactory"
          "factory-db-pfactory"
          "factory-db-tfactory"
          "minio-creds"
          "oauth2-proxy-cfactory"
          "oauth2-proxy-observe"
          "oauth2-proxy-odin"
          "observe-root"
          "otel-otlp-auth"
          "cfactory-api-keys"
          "odin-ssh-key"
        ])
      ))
    ];
  };
}
