# shellcheck shell=bash
# Shared sandbox policy for agent-review and agent-implement (#2757). Concatenated ahead of the
# launcher by Nix, never sourced; the launcher defines `refuse` and sets `set -euo pipefail`.
# The globals set here are read by the launchers, and the exec helpers are called by them only.
# shellcheck disable=SC2034,SC2329

# A caller's GIT_* could point the repo mounts at home.
for var in GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_CEILING_DIRECTORIES GIT_CONFIG GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GIT_CONFIG_COUNT GIT_NAMESPACE GIT_PREFIX; do
  unset "$var"
done

# Sets root, common and home.
sandbox_repo_checks() {
  [[ $(git rev-parse --is-inside-work-tree 2>/dev/null) == true ]] || refuse 'current directory is not a git worktree'
  root=$(realpath -e -- "$(git rev-parse --show-toplevel)")
  common=$(realpath -e -- "$(git rev-parse --git-common-dir)")
  home=$(realpath -e -- "$HOME")
  local path
  for path in "$root" "$common"; do
    [[ $path != "$home" && $home != "$path/"* && $path != / ]] || refuse 'repo must not contain the home directory'
  done
}

# Sets ro_paths, the host paths that exist, as --ro-bind arguments for bwrap.
sandbox_ro_paths() {
  ro_paths=()
  local path
  for path in /nix /etc /usr /bin /lib /lib64 /run/current-system /run/systemd/resolve /run/nscd; do
    [[ ! -e $path ]] || ro_paths+=(--ro-bind "$path" "$path")
  done
}

# Needs root and common. Sets safe_path.
# A relative PATH entry, or one inside the repo, would find a tool planted there,
# and it would run as the parent, outside the tool's own sandbox.
sandbox_safe_path() {
  safe_path=
  local entries entry real
  IFS=: read -ra entries <<<"${PATH:-}"
  for entry in "${entries[@]}"; do
    case $entry in
      /*) ;;
      *) continue ;;
    esac
    # Compare the resolved path, so `/./`, `..` and symlinks cannot reach into the repo.
    real=$(realpath -e -- "$entry" 2>/dev/null) || continue
    case $real/ in
      "$root"/* | "$common"/*) continue ;;
    esac
    safe_path+=${safe_path:+:}$entry
  done
}

# Creates the file, empty and private, so a later bind has something to land on. An existing
# file is refused. Needs root, common and home.
sandbox_check_out_file() {
  local path=$1 parent lexical protected
  [[ $path == /* ]] || refuse 'output file must be an absolute path'
  parent=$(dirname -- "$path")
  [[ -d $parent && ! -L $parent && -O $parent ]] || refuse 'output file parent must be a real directory owned by the caller'
  # The content is model-controlled, so a file in ~/.config/autostart would run later outside the sandbox.
  local rp xr allowed=''
  rp=$(realpath -e -- "$parent")
  [[ $rp == /tmp/* ]] && allowed=1
  if [[ -n ${XDG_RUNTIME_DIR:-} ]] && xr=$(realpath -e -- "$XDG_RUNTIME_DIR" 2>/dev/null) && [[ $xr != / && -O $xr && $rp == "$xr"/* ]]; then
    allowed=1
  fi
  [[ -n $allowed ]] || refuse 'output file parent must be under /tmp or XDG_RUNTIME_DIR'
  lexical=$(realpath -m -s -- "$path")
  [[ $lexical == "$(realpath -m -- "$path")" ]] || refuse 'output file must not use symlinks'
  for protected in "$root" "$common" "$home/.codex" "$home/.gemini" /etc /nix; do
    protected=$(realpath -m -- "$protected")
    [[ $lexical != "$protected" && $lexical != "$protected/"* ]] || refuse 'output file is inside a protected path'
  done
  (
    set -o noclobber
    umask 077
    : >"$lexical"
  ) 2>/dev/null || refuse 'output file already exists or cannot be created'
  [[ -f $lexical && ! -L $lexical && $(stat -c %h -- "$lexical") == 1 ]] || refuse 'output file is not a plain single-link file'
}

# sandbox_exec_bwrap <extra bwrap args…> -- <command…>. Needs root, home, safe_path.
# The extra args come after the fixed mounts, so they can bind into /tmp and /home.
sandbox_exec_bwrap() {
  local extra=()
  while (($#)) && [[ $1 != -- ]]; do
    extra+=("$1")
    shift
  done
  [[ ${1:-} == -- ]] || refuse 'sandbox_exec_bwrap: missing --'
  shift
  sandbox_ro_paths
  # bwrap passes inherited descriptors on to the tool.
  local fd n
  for fd in /proc/self/fd/*; do
    n=${fd##*/}
    [[ $n =~ ^[0-9]+$ ]] && ((n > 2)) && eval "exec $n>&-" 2>/dev/null || true
  done
  # env -i: an exported function or LD_* in the caller's environment would run inside bwrap itself.
  "$(type -P env)" -i "$(type -P bwrap)" "${ro_paths[@]}" \
    --tmpfs /nix/var/nix/daemon-socket \
    --dev /dev --proc /proc --tmpfs /tmp --tmpfs /home \
    --unshare-pid --unshare-ipc --die-with-parent \
    --clearenv \
    --setenv HOME "$home" \
    --setenv PATH "$safe_path" --setenv LANG "${LANG:-}" \
    --setenv TERM "${TERM:-dumb}" --setenv SSL_CERT_FILE /etc/ssl/certs/ca-certificates.crt \
    --setenv NIX_REMOTE 'local?read-only=true' \
    --setenv NIX_CONFIG 'experimental-features = nix-command flakes read-only-local-store' \
    "${extra[@]}" \
    -- "$@"
}

# Runs inside the new namespaces; sandbox_exec_unshare ships it with `declare -f`.
# Arguments: tool_path run_path home uid gid, then the policy, `--`, the command.
#   --rw DIR / --ro DIR   bind a host directory (--ro read-only), parents before children
#   --file FILE           bind one host file read-write, last
#   --sub-ro PATH         read-only bind in place; a trailing / makes a missing directory first
#   --sub-mask PATH=SRC   bind the file SRC over PATH if PATH exists, read-only
#   --sub-tmpfs PATH      empty tmpfs over PATH if it is a directory
#   --chdir DIR, --env NAME=VALUE
# Any failed step aborts before the command starts.
# shellcheck disable=SC2329  # shipped into the namespace with declare -f, so never called here
sandbox_setup() {
  set -euo pipefail
  local tool_path=$1 run_path=$2 home=$3 uid=$4 gid=$5
  shift 5
  PATH=$tool_path
  local kinds=() paths=() subs=() masks=() tmpfss=() chdir='' envs=()
  while (($#)); do
    case $1 in
      --rw | --ro | --file) kinds+=("${1#--}") paths+=("$2") ;;
      --sub-ro) subs+=("$2") ;;
      --sub-mask) masks+=("$2") ;;
      --sub-tmpfs) tmpfss+=("$2") ;;
      --chdir) chdir=$2 ;;
      --env) envs+=("$2") ;;
      --)
        shift
        break
        ;;
      *)
        echo "sandbox: unknown policy option: $1" >&2
        exit 2
        ;;
    esac
    shift 2 || {
      echo 'sandbox: option without a value' >&2
      exit 2
    }
  done
  [[ -n $chdir && $# -gt 0 ]] || {
    echo 'sandbox: missing --chdir or command' >&2
    exit 2
  }

  mount --make-rprivate /
  [[ -d /mnt ]] || {
    echo 'sandbox: /mnt is missing' >&2
    exit 2
  }
  mount -t tmpfs tmpfs /mnt

  # Staging: whatever must survive the tmpfs covers goes through /mnt.
  mkdir /mnt/dev /mnt/resolve /mnt/nscd /mnt/mask
  local i n
  for i in "${!paths[@]}"; do
    if [[ ${kinds[i]} == file ]]; then
      [[ -f ${paths[i]} && ! -L ${paths[i]} ]] || {
        echo "sandbox: not a plain file: ${paths[i]}" >&2
        exit 2
      }
      : >"/mnt/s$i"
    else
      [[ -d ${paths[i]} ]] || {
        echo "sandbox: not a directory: ${paths[i]}" >&2
        exit 2
      }
      mkdir "/mnt/s$i"
    fi
    mount --bind "${paths[i]}" "/mnt/s$i"
  done
  for n in null zero full random urandom tty; do
    : >"/mnt/dev/$n"
    mount --bind "/dev/$n" "/mnt/dev/$n"
  done
  # The mask sources are copied now: they may live in a tree that is covered below.
  for i in "${!masks[@]}"; do cp -- "${masks[i]#*=}" "/mnt/mask/$i"; done
  [[ ! -d /run/systemd/resolve ]] || mount --bind /run/systemd/resolve /mnt/resolve
  [[ ! -d /run/nscd ]] || mount --bind /run/nscd /mnt/nscd
  local cs
  cs=$(readlink /run/current-system)

  # rbind: /usr/bin (envfs) and /nix/store are submounts that a plain bind would drop.
  # /bin stays as the host has it, already read-only.
  local p
  for p in /nix /etc /usr /lib /lib64; do
    [[ -e $p ]] || continue
    mount --rbind "$p" "$p"
    mount -o remount,bind,ro "$p"
  done
  mount -t tmpfs tmpfs /nix/var/nix/daemon-socket

  local d keep=' nix etc usr lib lib64 bin proc dev mnt '
  for d in /*; do
    n=${d#/}
    [[ -d $d && ! -L $d ]] || continue
    [[ $keep == *" $n "* ]] && continue
    mount -t tmpfs tmpfs "$d"
  done

  # mode=0755: a default tmpfs mode makes opening /dev/null fail.
  mount -t tmpfs -o mode=0755 tmpfs /dev
  for n in null zero full random urandom tty; do
    : >"/dev/$n"
    mount --bind "/mnt/dev/$n" "/dev/$n"
    umount "/mnt/dev/$n"
  done
  mkdir /dev/pts /dev/shm
  mount -t devpts -o newinstance,ptmxmode=0666 devpts /dev/pts
  ln -s pts/ptmx /dev/ptmx
  mount -t tmpfs tmpfs /dev/shm
  ln -s /proc/self/fd /dev/fd
  ln -s fd/0 /dev/stdin
  ln -s fd/1 /dev/stdout
  ln -s fd/2 /dev/stderr

  # A symlink, so a bind would resolve it.
  ln -s "$cs" /run/current-system
  mkdir -p /run/systemd/resolve /run/nscd
  mount --move /mnt/resolve /run/systemd/resolve
  mount --move /mnt/nscd /run/nscd

  for i in "${!paths[@]}"; do
    if [[ ${kinds[i]} == file ]]; then
      mkdir -p -- "$(dirname -- "${paths[i]}")"
      [[ -e ${paths[i]} ]] || : >"${paths[i]}"
    else
      mkdir -p -- "${paths[i]}"
    fi
  done
  # File binds go last, after every directory bind, so none is hidden by a later one.
  for i in "${!paths[@]}"; do
    [[ ${kinds[i]} != file ]] || continue
    mount --move "/mnt/s$i" "${paths[i]}"
    [[ ${kinds[i]} != ro ]] || mount -o remount,bind,ro "${paths[i]}"
  done

  for p in "${subs[@]}"; do
    if [[ $p == */ ]]; then
      p=${p%/}
      [[ -e $p ]] || mkdir -p -- "$p"
    fi
    [[ -e $p ]] || {
      echo "sandbox: missing read-only path: $p" >&2
      exit 2
    }
    mount --bind "$p" "$p"
    mount -o remount,bind,ro "$p"
  done
  for i in "${!masks[@]}"; do
    p=${masks[i]%%=*}
    [[ -e $p ]] || continue
    mount --bind "/mnt/mask/$i" "$p"
    mount -o remount,bind,ro "$p"
  done
  for p in "${tmpfss[@]}"; do
    [[ ! -d $p ]] || mount -t tmpfs tmpfs "$p"
  done

  for i in "${!paths[@]}"; do
    [[ ${kinds[i]} == file ]] || continue
    mount --move "/mnt/s$i" "${paths[i]}"
  done

  # Fails while any staged mount is left.
  umount /mnt
  mount -t tmpfs tmpfs /mnt

  local fd
  for fd in /proc/self/fd/*; do
    n=${fd##*/}
    [[ $n =~ ^[0-9]+$ ]] && ((n > 2)) && eval "exec $n>&-" 2>/dev/null || true
  done
  cd -- "$chdir"
  exec unshare --user --map-user="$uid" --map-group="$gid" -- env -i \
    PATH="$run_path" HOME="$home" LANG="${LANG:-}" TERM="${TERM:-dumb}" \
    SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt NIX_REMOTE='local?read-only=true' \
    NIX_CONFIG='experimental-features = nix-command flakes read-only-local-store' \
    "${envs[@]}" "$@"
}

# sandbox_exec_unshare <policy…> -- <command…>, for agy: two nested user namespaces built with
# unshare and mount, because bwrap forces nosuid and that breaks agy's own --sandbox (#2298).
# Needs home and safe_path. The tools are resolved to the directories they have now, because
# /run/wrappers is hidden inside.
sandbox_exec_unshare() {
  local uid gid name bin dir tool_path=''
  uid=$(id -u)
  gid=$(id -g)
  for name in unshare mount umount bash env mkdir ln cp readlink id; do
    bin=$(type -P "$name") || refuse "sandbox: missing tool: $name"
    [[ $bin == /* && $bin != /run/wrappers/* ]] || refuse "sandbox: $name is not a plain absolute path: $bin"
    dir=$(dirname -- "$bin")
    [[ :$tool_path: == *":$dir:"* ]] || tool_path+=${tool_path:+:}$dir
  done
  # env -i: a caller's BASH_FUNC_mount%% or LD_PRELOAD would otherwise act inside the namespace.
  "$(type -P env)" -i PATH="$tool_path" LANG="${LANG:-}" TERM="${TERM:-dumb}" \
    "$(type -P unshare)" --user --map-root-user --mount --pid --fork --mount-proc --kill-child -- \
    "$(type -P bash)" -c "$(declare -f sandbox_setup); sandbox_setup \"\$@\"" sandbox \
    "$tool_path" "$safe_path" "$home" "$uid" "$gid" "$@"
}
