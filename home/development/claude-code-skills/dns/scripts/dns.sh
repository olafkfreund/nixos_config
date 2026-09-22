#!/usr/bin/env bash
# dns — manage GoDaddy DNS records from the CLI.
# Companion to the `dns` Claude Code skill at ~/.claude/skills/dns/.
# Decrypts the GoDaddy API credentials from agenix at invocation time;
# never writes them to disk or env.
set -euo pipefail

NIXOS_DIR="${GODADDY_NIXOS_DIR:-$HOME/.config/nixos}"
SECRET_REL="${GODADDY_SECRET_REL:-secrets/api-godaddy.age}"
SSH_KEY="${GODADDY_SSH_KEY:-$HOME/.ssh/id_ed25519}"
API="https://api.godaddy.com/v1"

usage() {
  cat <<'EOF'
Usage: dns <subcommand> [args...]

Subcommands:
  domains                                       List all domains in the account
  list <domain>                                 List all records for a domain (table)
  list <domain> json                            ... as raw JSON
  get  <domain> <type> <name>                   Get one record set by type+name
  add  <domain> <name> <type> <value> [ttl]     Upsert (replaces same name+type set)
  rm   <domain> <name> <type>                   Delete all records of name+type
  verify <domain> <name> <type> <expected>      Compare GoDaddy record to expected value
  check  <fqdn> [<type>]                        Resolve via dig (Cloudflare + Google DNS)
  help                                          Show this help

Names:
  Apex of example.com  → name "@"
  www.example.com      → name "www", domain "example.com"
EOF
}

if [ $# -eq 0 ] || [ "$1" = "help" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  usage
  exit 0
fi

load_creds() {
  if [ ! -f "$NIXOS_DIR/$SECRET_REL" ]; then
    echo "ERROR: missing GoDaddy secret at $NIXOS_DIR/$SECRET_REL" >&2
    echo "Override with GODADDY_NIXOS_DIR=... GODADDY_SECRET_REL=..." >&2
    exit 1
  fi
  # agenix indexes secrets.nix by the path string used in the command,
  # so we must run from NIXOS_DIR with a relative path — not an absolute one.
  local plaintext
  if ! plaintext=$(cd "$NIXOS_DIR" && nix run github:ryantm/agenix -- -d "$SECRET_REL" -i "$SSH_KEY" 2>&1); then
    echo "ERROR: failed to decrypt $NIXOS_DIR/$SECRET_REL (key=$SSH_KEY)" >&2
    printf '%s\n' "$plaintext" >&2
    exit 1
  fi
  KEY=$(printf '%s\n' "$plaintext" | awk 'NR==2')
  SECRET=$(printf '%s\n' "$plaintext" | awk 'NR==4')
  if [ -z "${KEY:-}" ] || [ -z "${SECRET:-}" ]; then
    echo "ERROR: could not parse KEY/SECRET from decrypted secret" >&2
    exit 1
  fi
  AUTH="Authorization: sso-key $KEY:$SECRET"
}

api() {
  local method="$1"
  local path="$2"
  local data="${3:-}"
  local body status
  body=$(mktemp)
  if [ -n "$data" ]; then
    status=$(curl -sS -o "$body" -w '%{http_code}' -X "$method" \
      -H "$AUTH" -H 'Accept: application/json' -H 'Content-Type: application/json' \
      -d "$data" "$API$path")
  else
    status=$(curl -sS -o "$body" -w '%{http_code}' -X "$method" \
      -H "$AUTH" -H 'Accept: application/json' "$API$path")
  fi
  if [ "${status:0:1}" = "2" ]; then
    cat "$body"
    rm -f "$body"
  else
    echo "ERROR: $method $API$path → HTTP $status" >&2
    cat "$body" >&2
    echo >&2
    rm -f "$body"
    exit 1
  fi
}

cmd="$1"
shift

case "$cmd" in
  domains)
    load_creds
    api GET /domains | jq -r '.[] | [.domain, .status, .expires] | @tsv' \
      | {
        printf 'DOMAIN\tSTATUS\tEXPIRES\n'
        cat
      } | column -t -s $'\t'
    ;;

  list)
    domain="${1:?usage: dns list <domain> [json]}"
    fmt="${2:-table}"
    load_creds
    json=$(api GET "/domains/$domain/records")
    if [ "$fmt" = "json" ]; then
      printf '%s\n' "$json" | jq
    else
      printf '%s\n' "$json" \
        | jq -r '.[] | [.type, .name, (.data // .target // ""), .ttl] | @tsv' \
        | {
          printf 'TYPE\tNAME\tVALUE\tTTL\n'
          cat
        } | column -t -s $'\t'
    fi
    ;;

  get)
    domain="${1:?usage: dns get <domain> <type> <name>}"
    type="${2:?}"
    name="${3:?}"
    load_creds
    api GET "/domains/$domain/records/$type/$name" | jq
    ;;

  add)
    domain="${1:?usage: dns add <domain> <name> <type> <value> [ttl]}"
    name="${2:?}"
    type="${3:?}"
    value="${4:?}"
    ttl="${5:-3600}"
    load_creds
    payload=$(jq -nc --arg data "$value" --argjson ttl "$ttl" '[{data:$data, ttl:$ttl}]')
    api PUT "/domains/$domain/records/$type/$name" "$payload" >/dev/null
    echo "OK upserted $type $name.$domain → $value (ttl $ttl)"
    ;;

  rm)
    domain="${1:?usage: dns rm <domain> <name> <type>}"
    name="${2:?}"
    type="${3:?}"
    load_creds
    api DELETE "/domains/$domain/records/$type/$name" >/dev/null
    echo "OK deleted $type $name.$domain"
    ;;

  verify)
    domain="${1:?usage: dns verify <domain> <name> <type> <expected>}"
    name="${2:?}"
    type="${3:?}"
    expected="${4:?}"
    load_creds
    actual=$(api GET "/domains/$domain/records/$type/$name" | jq -r '.[0].data // .[0].target // empty')
    if [ "$actual" = "$expected" ]; then
      echo "MATCH  $type $name.$domain = $actual"
    else
      echo "DIFFER expected=$expected  actual=${actual:-<empty>}"
      exit 1
    fi
    ;;

  check)
    fqdn="${1:?usage: dns check <fqdn> [<type>]}"
    type="${2:-A}"
    echo "1.1.1.1: $(dig +short @1.1.1.1 "$fqdn" "$type" | tr '\n' ' ' | sed 's/ $//')"
    echo "8.8.8.8: $(dig +short @8.8.8.8 "$fqdn" "$type" | tr '\n' ' ' | sed 's/ $//')"
    ;;

  *)
    echo "ERROR: unknown subcommand: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac
