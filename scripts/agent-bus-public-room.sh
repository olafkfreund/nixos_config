#!/usr/bin/env bash
# #nixarchy-agents -- the public room, and the fence that makes it safe.
#
# The bind: federation is off, so an outside agent needs an account HERE, and
# the only scriptable way to mint one is the registration token. A room that is
# genuinely self-serve therefore means a registration token that is genuinely
# public -- and the moment that token is public, "ban each guest from #agents
# as you provision them" (scripts/agent-bus-guest.sh) stops being a boundary,
# because nobody has to ask us for an account any more.
#
# So the boundary moves from a per-account ban to a room property: #agents
# becomes invite-only, and the invite is issued with the admin token, which
# lives in agenix on our hosts and is never handed out. A self-minted account
# holds the registration token and nothing else, so it can create itself, join
# #nixarchy-agents, and get 403 on #agents forever.
#
# Guest accounts would have been lazier -- no token handout at all -- but
# continuwuity has no allow_guest_registration and answers
# M_GUEST_ACCESS_FORBIDDEN unconditionally. Ruled out, not overlooked.
#
# ORDER MATTERS. `fence` must not run until every host is deployed with
# MATRIX_ADMIN_TOKEN_FILE wired, because from that moment every newly
# registered session -- and every subagent, each of which is its own account --
# can only get in by inviting itself. `create` is additive and safe any time.
set -euo pipefail

HOMESERVER="${MATRIX_HOMESERVER:-https://matrix.freundcloud.org.uk}"
SERVER_NAME="${MATRIX_SERVER_NAME:-freundcloud.org.uk}"
BASE="$HOMESERVER/_matrix/client/v3"
PUBLIC_ALIAS="nixarchy-agents"
MAIN_ROOM="#agents:$SERVER_NAME"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat >&2 <<EOF
usage: $0 <command>

  create   create #$PUBLIC_ALIAS:$SERVER_NAME (public join, world-readable)
  fence    make $MAIN_ROOM invite-only -- DEPLOY EVERY HOST FIRST
  unfence  put $MAIN_ROOM back to public join (the undo for fence)
  status   show the join rule and history visibility of both rooms
EOF
  exit 2
}
[ $# -eq 1 ] || usage

admin="$(age -d -i "$HOME/.ssh/id_ed25519" "$REPO/secrets/agent-bus-matrix-token.age" 2>/dev/null || true)"
[ -n "$admin" ] || {
  echo "cannot decrypt secrets/agent-bus-matrix-token.age" >&2
  exit 1
}

enc() { python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1],safe=""))' "$1"; }

api() { # api METHOD PATH [BODY]
  local m=$1 p=$2 b=${3:-}
  if [ -n "$b" ]; then
    curl -sS -X "$m" -H "Authorization: Bearer $admin" -H 'Content-Type: application/json' -d "$b" "$BASE$p"
  else
    curl -sS -X "$m" -H "Authorization: Bearer $admin" "$BASE$p"
  fi
}

resolve() { # resolve ALIAS -> room id, empty if it does not exist
  api GET "/directory/room/$(enc "$1")" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("room_id",""))'
}

set_join_rule() { # set_join_rule ROOM_ID public|invite
  local id=$1 rule=$2 out
  out="$(api PUT "/rooms/$(enc "$id")/state/m.room.join_rules" \
    "$(python3 -c 'import json,sys;print(json.dumps({"join_rule":sys.argv[1]}))' "$rule")")"
  grep -q '"errcode"' <<<"$out" && {
    echo "failed: $out" >&2
    exit 1
  }
  echo "$MAIN_ROOM join_rule -> $rule"
}

case "$1" in
  create)
    existing="$(resolve "#$PUBLIC_ALIAS:$SERVER_NAME")"
    if [ -n "$existing" ]; then
      echo "already exists: $existing"
      exit 0
    fi
    # world_readable so a human can read the room in a client without an account
    # at all -- the point of a public room is that it is readable before you
    # commit to joining it. Room version 12 rejects listing the creator in
    # power_levels.users, so only `invite` is set here; the creator's power is
    # implicit and infinite (learned the hard way in #1676).
    body="$(
      python3 - "$PUBLIC_ALIAS" <<'PY'
import json, sys
alias = sys.argv[1]
print(json.dumps({
    "room_alias_name": alias,
    "name": "nixarchy agents",
    "topic": "Public room for coding agents working on nixarchy. Assume everything here is world-readable.",
    "preset": "public_chat",
    "visibility": "public",
    "initial_state": [
        {"type": "m.room.history_visibility", "state_key": "",
         "content": {"history_visibility": "world_readable"}},
        {"type": "m.room.guest_access", "state_key": "",
         "content": {"guest_access": "forbidden"}},
    ],
    "power_level_content_override": {"invite": 0, "events_default": 0},
}))
PY
    )"
    out="$(api POST "/createRoom" "$body")"
    id="$(python3 -c 'import json,sys;print(json.load(sys.stdin).get("room_id",""))' <<<"$out")"
    [ -n "$id" ] || {
      echo "createRoom failed: $out" >&2
      exit 1
    }
    echo "created #$PUBLIC_ALIAS:$SERVER_NAME -> $id"
    ;;

  fence)
    id="$(resolve "$MAIN_ROOM")"
    [ -n "$id" ] || {
      echo "cannot resolve $MAIN_ROOM" >&2
      exit 1
    }
    cat >&2 <<EOF
About to make $MAIN_ROOM invite-only.

From that moment a newly registered identity can only join by inviting itself
with the admin token. Every host must already be deployed with
MATRIX_ADMIN_TOKEN_FILE wired, or new sessions and subagents get 403.

Existing members are unaffected -- Matrix does not evict on a join-rule change.
Undo with: $0 unfence
EOF
    read -rp "type 'fence' to continue: " confirm
    [ "$confirm" = "fence" ] || {
      echo "aborted" >&2
      exit 1
    }
    set_join_rule "$id" invite
    ;;

  unfence)
    id="$(resolve "$MAIN_ROOM")"
    [ -n "$id" ] || {
      echo "cannot resolve $MAIN_ROOM" >&2
      exit 1
    }
    set_join_rule "$id" public
    ;;

  status)
    for alias in "$MAIN_ROOM" "#$PUBLIC_ALIAS:$SERVER_NAME"; do
      id="$(resolve "$alias")"
      if [ -z "$id" ]; then
        echo "$alias: does not exist"
        continue
      fi
      jr="$(api GET "/rooms/$(enc "$id")/state/m.room.join_rules" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("join_rule","?"))')"
      hv="$(api GET "/rooms/$(enc "$id")/state/m.room.history_visibility" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("history_visibility","?"))')"
      echo "$alias: join=$jr history=$hv  ($id)"
    done
    ;;

  *) usage ;;
esac
