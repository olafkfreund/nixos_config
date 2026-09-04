#!/usr/bin/env bash
# Provision an outside collaborator's agent onto the bus, in the guest room only.
#
# The awkward part this exists to handle: federation is off, so an external
# agent cannot bring its own identity from its own homeserver -- it needs an
# account here. But one shared registration token mints every account the same
# way, so the server cannot tell an outside account from one of ours at
# creation time. There is no config switch that separates them.
#
# The separation is therefore per-account and it is a BAN, applied before the
# account has ever joined anything. Matrix lets you ban a user who was never a
# member, and `#agents` is `history_visibility: shared` -- so a guest who is
# banned first never sees a single line of it, while one who is banned later
# has already read everything. Order matters more than it looks.
#
# `#agents` cannot simply be made invite-only instead: every Claude Code
# session registers a fresh account and self-joins, so an invite-only main room
# would lock out every future session of our own.
set -euo pipefail

usage() {
  echo "usage: $0 <name>   # e.g. $0 acme-research" >&2
  exit 2
}
[ $# -eq 1 ] || usage
name="$(tr '[:upper:]' '[:lower:]' <<<"$1" | tr -c 'a-z0-9._=-' '-' | sed 's/^-*//;s/-*$//')"
[ -n "$name" ] || usage

HOMESERVER="${MATRIX_HOMESERVER:-https://matrix.freundcloud.org.uk}"
SERVER_NAME="${MATRIX_SERVER_NAME:-freundcloud.org.uk}"
BASE="$HOMESERVER/_matrix/client/v3"
MAIN_ROOM="#agents:$SERVER_NAME"
GUEST_ROOM="#agents-guests:$SERVER_NAME"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

api() { # api METHOD PATH TOKEN [BODY]
  local m=$1 p=$2 t=$3 b=${4:-}
  if [ -n "$b" ]; then
    curl -sS -X "$m" -H "Authorization: Bearer $t" -H 'Content-Type: application/json' -d "$b" "$BASE$p"
  else
    curl -sS -X "$m" -H "Authorization: Bearer $t" "$BASE$p"
  fi
}
enc() { python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=""))' "$1"; }
resolve() { api GET "/directory/room/$(enc "$1")" "$2" | python3 -c 'import json,sys;print(json.load(sys.stdin)["room_id"])'; }

# The admin credential lives in agenix, not on disk. It is @agent-p510, which
# created #agents and is the only account with power there -- see secrets.nix.
admin="$(cd "$REPO" && agenix -d secrets/agent-bus-matrix-token.age | tr -d '\n')"
[ -n "$admin" ] || {
  echo "could not decrypt the admin token" >&2
  exit 1
}

regtok="$(cat "${MATRIX_REGISTRATION_TOKEN_FILE:-/run/agenix/matrix-registration-token}")"
[ -n "$regtok" ] || {
  echo "no registration token readable" >&2
  exit 1
}

main_id="$(resolve "$MAIN_ROOM" "$admin")"
guest_id="$(resolve "$GUEST_ROOM" "$admin")"

# 1. Mint the account. Same single-stage UIA the MCP server uses.
session="$(curl -sS -X POST -H 'Content-Type: application/json' -d '{}' "$BASE/register" \
  | python3 -c 'import json,sys;print(json.load(sys.stdin).get("session",""))')"
password="$(head -c 18 /dev/urandom | base64 | tr -d '/+=')"
body="$(
  python3 - "$name" "$password" "$regtok" "$session" <<'PY'
import json,sys
u,p,t,s = sys.argv[1:5]
print(json.dumps({"username": f"guest-{u}", "password": p, "inhibit_login": False,
                  "auth": {"type":"m.login.registration_token","token":t,"session":s}}))
PY
)"
reg="$(curl -sS -X POST -H 'Content-Type: application/json' -d "$body" "$BASE/register")"
user_id="$(python3 -c 'import json,sys;d=json.load(sys.stdin);print(d.get("user_id") or "")' <<<"$reg")"
[ -n "$user_id" ] || {
  echo "registration failed: $reg" >&2
  exit 1
}
gtoken="$(python3 -c 'import json,sys;print(json.load(sys.stdin)["access_token"])' <<<"$reg")"

# 2. Ban from #agents BEFORE the account has ever looked at it. This is the
#    whole security boundary; everything else is convenience.
ban="$(api POST "/rooms/$(enc "$main_id")/ban" "$admin" \
  "$(python3 -c 'import json,sys;print(json.dumps({"user_id":sys.argv[1],"reason":"external guest: guest room only"}))' "$user_id")")"
grep -q '"errcode"' <<<"$ban" && {
  echo "BAN FAILED, refusing to continue: $ban" >&2
  exit 1
}

# 3. Invite to the guest room.
api POST "/rooms/$(enc "$guest_id")/invite" "$admin" \
  "$(python3 -c 'import json,sys;print(json.dumps({"user_id":sys.argv[1]}))' "$user_id")" >/dev/null

api PUT "/profile/$(enc "$user_id")/displayname" "$gtoken" \
  "$(python3 -c 'import json,sys;print(json.dumps({"displayname":sys.argv[1]}))' "$name")" >/dev/null || true

cat <<EOF

Provisioned $user_id

  Give them these, over a channel you trust:

    MATRIX_HOMESERVER=$HOMESERVER
    MATRIX_SERVER_NAME=$SERVER_NAME
    AGENT_BUS_ROOM=$GUEST_ROOM
    AGENT_BUS_NAME=$name
    access token: $gtoken

  They run agent-bus-mcp with those. Do NOT give them the registration token:
  that mints accounts, and an account they mint themselves is not banned from
  #agents.

  Verified: banned from $MAIN_ROOM, invited to $GUEST_ROOM.
EOF
