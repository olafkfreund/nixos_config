---
name: gog
description: >-
  Operate Google Workspace from the terminal via the `gog` CLI (gogcli).
  Use for checking and replying to Gmail, managing Google Tasks, reading and
  creating Calendar events, Google Chat (spaces/DMs/messages), Meet spaces,
  Contacts, Drive/Docs/Sheets, and more. Triggers on `/gog`, `/gog mail`,
  `/gog tasks`, `/gog events`, `/gog chat`, `/gog meet`, or any request to
  check/read/reply/send email, list or add tasks, see today's agenda, or
  message someone on Chat for the user's Google account.
---

# gog — Google Workspace in the terminal

`gog` (gogcli) is installed system-wide. Treat this skill as the playbook for
driving it on this machine. Invoked as `/gog <area> [...]` — route to the
matching section below (mail, tasks, events, chat, meet, contacts, drive,
docs, sheets). With no area, show a short menu of what you can do.

## Environment (this machine)

```bash
export GOG_HOME="$HOME/.config/gogcli"   # config/data/state/keyring root
ACCT="olaf@freundcloud.com"              # default account; override with -a
```

- Auth is already provisioned (OAuth, **file** keyring). Always pass
  `-a "$ACCT"` for API calls and `--no-input` so any auth/keyring prompt
  fails fast instead of hanging.
- Use `-j` (JSON) for anything you need to parse, then **format it for the
  user** — never dump raw JSON. Use `--plain` (TSV) for quick human reads.
- Run `gog <area> --help` (or `gog schema <area> <cmd>`) to confirm flags
  before any write — the surface is large and flags differ per verb.

## Safety rules (read before any write)

- **Never print** access tokens, refresh tokens, OAuth client secrets, or
  keyring passwords. When inspecting auth, show status only.
- **Sending/replying to mail, deleting, or any mutation requires explicit
  user intent.** Draft first and show the user; only `send` after they
  confirm. Don't add `--force` unless the user asked for that exact change.
- Prefer `--dry-run` where supported; clean up any throwaway test objects.
- For pure reads, scope tightly (`--max`, date filters) and keep it read-only.

---

## mail — `gog gmail` (aliases: mail, email)

Check, read, reply, send, organise. Verbs: `search get raw thread labels
archive mark-read unread trash send forward autoreply drafts attachment`.

**Check / read:**

```bash
gog -a "$ACCT" --no-input -j gmail search "is:unread in:inbox" --max 15
gog -a "$ACCT" --no-input -j gmail search "newer_than:1d"          # today-ish
gog -a "$ACCT" --no-input -j gmail get <messageId> --sanitize-content
gog -a "$ACCT" --no-input -j gmail thread get <threadId> --sanitize-content
```

Format results as: time · from · subject (· label). Resolve `<messageId>`/
`<threadId>` from a prior `search`.

**Reply / send (confirm with user first):**

```bash
gog gmail send --help            # confirm reply/thread flags before using
# draft a reply in-thread, show it, then send on confirmation:
gog -a "$ACCT" --no-input gmail drafts create --thread <threadId> \
  --to <addr> --subject "Re: ..." --body-file /tmp/reply.txt
gog -a "$ACCT" --no-input gmail send ...     # only after the user says go
```

**Organise:** `gmail archive|mark-read|unread|trash <messageId>`,
`gmail labels list`, `gmail forward --to <addr> <messageId>`.

## tasks — `gog tasks` (alias: task)

Default list id is `@default` ("My Tasks").

```bash
gog -a "$ACCT" --no-input -j tasks lists                 # find list ids
gog -a "$ACCT" --no-input -j tasks list @default         # active tasks
gog -a "$ACCT" --no-input    tasks add @default --title "Buy milk" --due 2026-05-30
gog -a "$ACCT" --no-input    tasks done @default <taskId>
gog -a "$ACCT" --no-input    tasks delete @default <taskId>
```

Show as `☐ Title (due …)`; filter `.status != "completed"` for the open list.

## events — `gog calendar` (alias: cal)

```bash
gog -a "$ACCT" --no-input -j calendar calendars            # ids, colours, .selected
gog -a "$ACCT" --no-input -j calendar events --today       # primary, today
gog -a "$ACCT" --no-input -j calendar events <calId> --days 7   # one calendar
gog -a "$ACCT" --no-input -j calendar events --today --all # all calendars
gog -a "$ACCT" --no-input    calendar create <calId> --summary "..." --start ... --end ...
gog -a "$ACCT" --no-input    calendar respond <calId> <eventId> --status accepted
gog -a "$ACCT" --no-input -j calendar freebusy --from now --to tomorrow
```

For an agenda, query each `.selected==true` calendar and label by calendar.
Skip `.eventType == "workingLocation"` (Home/Office markers) unless asked.
Show as `HH:MM Summary` (bare summary for all-day).

## chat — `gog chat`

```bash
gog -a "$ACCT" --no-input -j chat spaces list
gog -a "$ACCT" --no-input -j chat messages list <spaceId> --max 20
gog -a "$ACCT" --no-input    chat messages send <spaceId> --text "..."   # confirm first
gog -a "$ACCT" --no-input    chat dm send <userId|email> --text "..."    # confirm first
```

## meet — `gog meet` (alias: meeting)

```bash
gog -a "$ACCT" --no-input -j meet create                  # new meeting space (link)
gog -a "$ACCT" --no-input -j meet get <meeting-code>
gog -a "$ACCT" --no-input -j meet history <meeting-code>  # past conferences
```

## and more

- **contacts / people:** `gog contacts list --max 20 -j`, `gog people me -j`
- **drive:** `gog drive ls --max 20 -j`, `gog drive search "<query>" -j`,
  `gog drive download <fileId>`
- **docs / sheets:** `gog docs cat <docId> -j`,
  `gog sheets get <sheetId> 'Sheet1!A1:D20' -j`
- **auth (read-only inspection):** `gog auth status`, `gog auth doctor`,
  `gog auth list` — never print token values.

## Output discipline

1. Run with `-j`, parse with `jq`, present a clean table/list to the user.
2. Lead with the answer (e.g. "3 unread"), then details.
3. For writes: show exactly what will change and get a yes before executing.
