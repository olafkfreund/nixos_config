# shellcheck shell=bash
# omarchy:summary=Notify on new unread mail; clicking the popup opens the thread
# omarchy:args=[--seed]
# omarchy:examples=omarchy-gmail-watch | omarchy-gmail-watch --seed

# Promotions and social are excluded deliberately: a notifier that fires for
# newsletters gets muted within a day, which defeats the point.
QUERY=${GOG_MAIL_QUERY:-"is:unread in:inbox -category:promotions -category:social"}
ACCOUNT=${GOG_ACCOUNT:-olaf@freundcloud.com}
MAX_NOTIFY=${GOG_MAIL_MAX_NOTIFY:-5}

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/omagog"
seen="$state_dir/seen-threads"
mkdir -p "$state_dir"

# First run must not fire a notification per already-unread mail. Seeding
# marks everything currently unread as old and stays silent.
seed=0
[[ ${1:-} == --seed || ! -f $seen ]] && seed=1

# Create the state file now, not after the fetch. A seed run that finds no
# matching mail would otherwise leave the file absent, so the next run would
# seed again and swallow the first real new mail -- the one notification that
# matters most.
((seed)) && : >>"$seen"

out=$(gog gmail search "$QUERY" --account "$ACCOUNT" --max 25 --json 2>/dev/null) || exit 0
ids=$(jq -r '.threads[]?.id // empty' <<<"$out")
[[ -n $ids ]] || exit 0

new=()
while read -r id; do
  [[ -n $id ]] || continue
  grep -qxF "$id" "$seen" 2>/dev/null || new+=("$id")
done <<<"$ids"

# Record before notifying: a crash mid-notify must not re-fire the whole batch
# on the next tick.
printf '%s\n' "${new[@]}" >>"$seen" 2>/dev/null
tail -n 500 "$seen" >"$seen.trim" 2>/dev/null && mv -f "$seen.trim" "$seen"

((seed)) && exit 0
((${#new[@]})) || exit 0

# One batched call maps thread ids to their Gmail URLs, rather than one API
# round trip per message.
urls=$(gog gmail url "${new[@]}" --account "$ACCOUNT" 2>/dev/null)

# Absolute path: the shell runs this argv itself, so it does not inherit the
# PATH this script was given.
opener=$(command -v xdg-open || echo xdg-open)

count=0
for id in "${new[@]}"; do
  ((count++ < MAX_NOTIFY)) || break
  url=$(awk -F'\t' -v i="$id" '$1==i{print $2; exit}' <<<"$urls")
  [[ -n $url ]] || url="https://mail.google.com/mail/u/0/#all/$id"
  subject=$(jq -r --arg i "$id" '.threads[]? | select(.id==$i) | .subject // "(no subject)"' <<<"$out")
  sender=$(jq -r --arg i "$id" '.threads[]? | select(.id==$i) | .from // ""' <<<"$out")
  # "Name <addr>" -> "Name"; bare addresses are left as they are.
  sender=${sender%% <*}
  omarchy-notification-send "${sender:-New mail}" "$subject" --exec "$opener" "$url" || true
done
