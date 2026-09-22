---
name: reddit-post
description: Draft a subreddit-appropriate Reddit post (title + body) that respects each community's
culture and rules, then optionally publish it via the Chrome browser automation tools. Reddit
punishes self-promotion hard, so this skill leads with value, matches the subreddit's voice, and
flags rule risks before you post. Use to write or post Reddit content.
when_to_use: When the user wants to post on Reddit, ask a question, share a project, or announce
something to a subreddit. Triggers — "/reddit-post", "write a Reddit post", "post this on r/X",
"share my project on Reddit", "draft a Show-and-tell for r/...", "ask r/X about Y".
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - WebFetch
---

# /reddit-post

Help the user draft — and optionally publish — a Reddit post that won't get
removed, downvoted, or flamed. Reddit is **not LinkedIn**: it is hostile to
marketing, allergic to fluff, and every subreddit has its own rules and voice.
This skill's main job is to keep the user *in-culture*.

## Inputs

- **subreddit** (arg or ask): e.g. `r/devops`, `r/programming`,
  `r/selfhosted`. Required — content must be tailored to it.
- **source / intent**: a topic, a project/repo to share, a question to ask, or a
  blog post/URL to discuss.
- **post type** (infer or ask): `discussion`, `question`, `show-and-tell`
  (project share), `guide/tutorial`, or `link`.
- **`--draft`**: write copy only, never offer to post.

## Reddit rules of survival (encode these)

1. **Read the room first.** Before drafting, check the subreddit's rules and what
   actually gets upvoted there (WebFetch `https://www.reddit.com/r/<sub>/about.json`
   for rules/description, and `.../top/.json?t=month` for tone). Match it.
2. **The 9:1 rule.** Reddit expects ~9 contributions for every 1 self-promo. If
   the user is sharing their own thing, **disclose it** ("I built this") — hidden
   self-promo is the fastest path to a ban.
3. **Title is 80% of the post.** Specific, honest, curiosity without clickbait.
   No "I made a thing", no ALL CAPS, no emoji. Many subs ban editorialised or
   listicle titles — check.
4. **Lead with value, not the pitch.** Open with the problem/insight. The link or
   product comes after you've earned attention. Markdown body, short paragraphs.
5. **No marketing voice.** Write like a person in a comment thread. Contractions,
   plain words, admit limitations — Redditors reward honesty and punish spin.
6. **Flair + format rules.** Some subs require flair, a `[tag]` in the title, or a
   specific format (e.g. weekly threads only). Flag these before posting.
7. **Engage after posting.** A post that ignores its comments dies. Note this to
   the user.

## Output format (always produce this)

```text
─── r/<subreddit> ───────────────────────────
TITLE: <one line, ≤300 chars, specific & honest>
FLAIR: <required flair if any, else "none required">

BODY (markdown):
<problem / context>

<the substance — value first>

<disclosure if self-promo, + link>

<a question to invite discussion>
──────────────────────────────────────────────
RULE CHECK:
- ✅/⚠️ self-promo disclosed
- ✅/⚠️ title format matches sub rules
- ✅/⚠️ flair requirement
- ⚠️ <any specific rule risk found in about.json>
──────────────────────────────────────────────
```

Save a copy to `/tmp/reddit-post-<sub>-<slug>.md`.

## Procedure (PARR — announce, run, verify, continue)

### 1. Recon the subreddit

WebFetch `https://www.reddit.com/r/<sub>/about.json` (rules, description,
`submission_type`) and skim `top/.json?t=month` for tone and what wins. If the
sub can't be fetched, ask the user to paste the sidebar rules. **Checkpoint:**
you know the rules, required flair/format, and the community's voice.

### 2. Draft title + body

Write to the output format, in the sub's voice, value-first. If it's the user's
own project, include an honest disclosure line. **Checkpoint:** title is
specific and rule-compliant; body leads with value; self-promo disclosed.

### 3. Rule-check pass

Fill the RULE CHECK block honestly. If anything is ⚠️, tell the user plainly and
suggest the fix (reword title, add flair, move to the weekly thread, etc.) before
posting. **Checkpoint:** no unaddressed ⚠️, or the user has accepted the risk.

### 4. Publish (only if not `--draft` and the user says so)

There is **no Reddit API / praw configured**, so posting = browser automation:

- Load the Chrome tools with `ToolSearch`
  (`select:mcp__claude-in-chrome__navigate,mcp__claude-in-chrome__form_input,...`),
  open `https://www.reddit.com/r/<sub>/submit`, fill title + body, set flair if
  required.
- **Do not auto-submit without explicit go-ahead** — this acts in the user's
  logged-in session. Confirm, then submit, then screenshot the live post.
- Fallback (always fine): hand the user the copy block to paste manually.

**Checkpoint:** user has the copy, or the post is live + screenshot confirms.

## Notes

- Never fake an account history or astroturf. If the user's account is brand new
  or low-karma, warn that many subs auto-remove such posts.
- Cross-posting the *same* text to many subs is spam and gets accounts banned —
  tailor per sub or use one home sub.
- For a coordinated push across blog + LinkedIn + Reddit, use
  `/content-marketer`, which calls this skill per target subreddit.
