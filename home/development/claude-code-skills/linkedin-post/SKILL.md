---
name: linkedin-post
description: Turn a blog post, PR/repo change, or raw topic into a polished, high-engagement LinkedIn post — plus an optional document/carousel "showcase" outline. Writes a strong scroll-stopping hook, scannable body, hashtags, and a CTA in a chosen voice, then (on request) posts it via the Chrome browser automation tools or hands you copy to paste. Use to write or refresh LinkedIn content.
when_to_use: When the user wants a LinkedIn post, a LinkedIn showcase/carousel, or to announce something (a launch, blog post, release, milestone) on LinkedIn. Triggers — "/linkedin-post", "write a LinkedIn post", "post this on LinkedIn", "LinkedIn carousel about X", "announce X on LinkedIn", "turn this blog post into a LinkedIn post".
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - WebFetch
---

# /linkedin-post

Help the user write — and optionally publish — a LinkedIn post or a showcase
(document/carousel) post. LinkedIn rewards **native, value-first, scannable**
content. This skill bakes those rules in so the output performs, not just reads.

## Inputs

- **source** (arg or ask): one of
  - a **topic/angle** ("our new test-quality pipeline"),
  - a **blog post / URL** (adapt it — don't dump it),
  - a **repo change / PR** (summarise what shipped and why it matters).
- **`--voice`** (optional): `personal` (default — first-person, story-led),
  `company` (we/our, product voice), or `thought-leader` (opinionated, takes a
  stance). If unset, ask which one in a single line.
- **`--carousel`**: also produce a showcase **document/carousel** outline
  (slide-by-slide), not just the text post.
- **`--draft`**: write copy only, never offer to post.

If only a rough idea is given, propose a sharp angle + the one takeaway and
confirm before drafting.

## What makes a LinkedIn post work (encode these)

1. **Hook in the first 1–3 lines.** Only ~140–210 chars show before the
   "…see more" fold. The first line must earn the click — a tension, a number,
   a contrarian claim, or a concrete result. No "I'm excited to announce".
2. **Whitespace is formatting.** Short lines. One idea per line. Blank line
   between thoughts. Mobile-first — assume a phone screen.
3. **Links kill reach.** LinkedIn deprioritises posts with outbound links in the
   body. Put the link in the **first comment** and say "(link in comments)".
4. **One clear CTA.** A question to drive comments, or "link in comments". Pick
   one — don't stack CTAs.
5. **3–5 hashtags max**, specific not generic (`#PlatformEngineering` not
   `#tech`). Place them at the end.
6. **No fluff.** No "revolutionary", no exclamation spam, no emoji soup
   (1–3 purposeful emoji at most, often zero for a technical audience).
7. **Length:** ~150–300 words / under ~1,300 chars for a text post. A story can
   run longer if every line earns its place.

## Output format (always produce this)

Return the post ready to paste, plus the comment link, clearly separated:

```
─── LINKEDIN POST ───────────────────────────
<hook line>

<body, short lines, whitespace>

<one CTA>

#Tag1 #Tag2 #Tag3
──────────────────────────────────────────────
FIRST COMMENT (post this as a reply to your own post):
👉 <url>   <one-line context>
──────────────────────────────────────────────
```

Save a copy to `/tmp/linkedin-post-<slug>.md` so the user can grab it later, and
SendUserFile it if useful.

## Showcase / carousel (`--carousel`)

LinkedIn "document posts" (PDF carousels) get strong reach and are ideal for
showcasing a product, an architecture, or a before/after. Produce a
slide-by-slide outline:

- **Slide 1 — cover:** big claim + who it's for. One line. Must work as a
  thumbnail.
- **Slides 2–N — one idea per slide:** ≤20 words each, a verb-led headline + a
  supporting line. Number them ("2/7").
- **Last slide — CTA:** what to do next + handle/link.
- Keep 6–10 slides. Note suggested visuals (diagram, terminal shot, metric).

If the user wants the actual PDF, offer to assemble it from screenshots they
have, or hand the outline to a design tool — don't fabricate a PDF silently.

## Procedure (PARR — announce, run, verify, continue)

### 1. Settle the angle
Confirm the source, the **one takeaway**, and the voice. If adapting a blog
post/URL, fetch it (WebFetch / Read) and pull the single most postable insight —
don't summarise the whole thing. **Checkpoint:** angle + voice agreed.

### 2. Draft the post
Write to the output format above. Apply every rule in "What makes a LinkedIn
post work". **Checkpoint:** hook is < ~140 chars and stands alone; no link in
body; 3–5 specific hashtags; one CTA.

### 3. (If `--carousel`) Draft the showcase
Produce the slide outline. **Checkpoint:** ≤10 slides, one idea each, cover works
as a thumbnail.

### 4. Self-critique pass
Reread as a phone user scrolling fast: does line 1 stop the scroll? Is it
skimmable? Cut anything that doesn't earn its line. Tighten.

### 5. Publish (only if not `--draft` and the user says so)
There is **no LinkedIn API configured**, so posting = browser automation.
Offer, don't assume:
- Load the Chrome tools with `ToolSearch` (`select:mcp__claude-in-chrome__...`),
  open `https://www.linkedin.com/feed/`, and drive the "Start a post" composer:
  paste the body, then add the link as the first comment after posting.
- **Warn** that this acts in their logged-in browser session; confirm first.
- Capture before/after frames if recording (gif_creator) so they can review.
- Fallback (always fine): just hand them the copy block to paste manually.

**Checkpoint:** either the user has the copy in hand, or the post is live and a
screenshot confirms it.

## Notes
- Never invent metrics or quotes. If a number would strengthen the hook, ask the
  user for the real one.
- Match the source product's positioning when `--voice company` (e.g. TFactory =
  "test quality, not test count"). Read the repo's blog/voice if available.
- One post per call. For multi-channel (blog + LinkedIn + Reddit) use
  `/content-marketer`, which orchestrates this skill.
