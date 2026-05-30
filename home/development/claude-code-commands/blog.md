---
description: Draft, stage, and publish a post to the freundcloud Jekyll blog (GitHub Pages)
argument-hint: "[--draft|--publish <slug>|--list] <title or notes>"
allowed-tools: Bash(*), Read, Write, Edit
---

# Blog publishing command

You write and publish posts for **<www.freundcloud.com>**, a Jekyll site
deployed to GitHub Pages from the repo `olafkfreund/WWW-Freundcloud`.
Posts are Markdown files in `_posts/`; pushing to `main` triggers the
`pages.yml` GitHub Action which builds the site and deploys it. Drafts
live in `_drafts/` and are never built/deployed until promoted.

Your input:

$ARGUMENTS

## Step 0 — Locate the blog repository

Find the repo root before doing anything else. In order:

1. If the current working directory is inside a git repo whose `origin`
   remote matches `WWW-Freundcloud` (case-insensitive), use that root:
   `git rev-parse --show-toplevel`.
2. Otherwise try `~/Source/GitHub/www-freundcloud`.
3. If neither exists, stop and tell me where the repo is (do **not**
   clone or guess). All file paths below are relative to this root.

Confirm you found a Jekyll blog: `_config.yml`, `_posts/`, and
`_layouts/post.html` must all exist. If not, stop and say so.

## Step 1 — Parse the mode from `$ARGUMENTS`

- `--list` → **List drafts.** Print the files in `_drafts/` (name +
  first-line title). Do nothing else.
- `--publish <slug>` → **Promote a draft.** Go to Step 4 with the draft
  `_drafts/<slug>.md`.
- `--draft <rest>` → **Draft only.** Write to `_drafts/`, no date, no
  push. Go to Step 2 then Step 3 (draft variant).
- anything else (plain text) → **Publish-ready.** Treat the text as the
  title/topic/notes. Go to Step 2 then Step 3 then Step 4.

## Step 2 — Gather what you need

From the input, derive: **title**, **angle**, **tags** (2–4, lowercase,
from the site's themes: devops, platform, cicd, nixos, ai, agents,
multicloud, meta, kubernetes, …), and a one-to-two-sentence **excerpt**.

Only ask me questions for fields you genuinely cannot infer. If the
input is a rich set of notes, infer everything and proceed — don't
interrogate. If it's just a bare title, ask for the angle and the tags
in a single batch, then continue.

Derive the **slug**: lowercase the title, replace non-alphanumerics with
single hyphens, trim leading/trailing hyphens. (e.g. "Moving a bank off
Bamboo" → `moving-a-bank-off-bamboo`.)

## Step 3 — Write the post

**Match the house voice.** Read `_posts/2026-05-29-welcome-to-the-blog.md`
first and mirror it: first-person, opinionated, working-out-loud, dry
wit, concrete over abstract, short paragraphs, `##` section headings,
fenced code blocks with a language where useful, occasional inline links
using Jekyll's `relative_url` filter for internal links
(e.g. `[the KB]({{ '/kb/' | relative_url }})`). No marketing fluff, no
"In today's fast-paced world" openers. Write something I'd actually post.

Length: aim 400–900 words unless the notes clearly want more or less.

**Front matter** — every field is required and read by the templates:

```yaml
---
layout: post
title: "<title>"
date: <YYYY-MM-DD HH:MM:SS +0100>
permalink: /blog/<slug>/
tags: [<tag>, <tag>]
comments: true
excerpt: >-
  <one-to-two sentence summary; shown on the blog index and in RSS>
---
```

For the **publish-ready** path: set `date` using real local time —
get it from `date "+%Y-%m-%d %H:%M:%S +0100"` — and write the file to
`_posts/<YYYY-MM-DD>-<slug>.md` (date prefix from `date +%F`).

For the **--draft** path: write to `_drafts/<slug>.md` and omit the
`date:` line entirely (Jekyll assigns the date at publish time). Do not
go to Step 4 — instead report the draft path and remind me I can publish
it later with `/blog --publish <slug>`.

**Safety:** if the target file already exists, stop and warn — never
overwrite an existing post or draft. Show me the proposed file (front
matter + body) and wait for my go-ahead before the publish step.

## Step 4 — Publish (publish-ready and --publish paths only)

1. If promoting a draft: read `_drafts/<slug>.md`, add a `date:` line
   with the current local time, write it to
   `_posts/<YYYY-MM-DD>-<slug>.md`, and `git rm` the draft.
2. **Validate locally** before pushing — run, from the repo root:
   `bundle exec jekyll build` (set `JEKYLL_ENV=production`). If the
   build fails, stop, show me the error, and do **not** push. This
   catches YAML/Liquid breakage that would otherwise fail the deploy.
3. Stage **only** the new post file (and the removed draft, if any) —
   never `git add -A`. Confirm with `git status` that nothing unexpected
   is staged.
4. Commit: `git commit -m "post: <title>"`.
5. Push: `git push origin main`. Never force-push.
6. Report the result: the live URL
   `https://www.freundcloud.com/blog/<slug>/`, the commit hash, and a
   note that the Pages Action takes ~1–2 minutes to build and deploy
   (link to the Actions tab so I can watch it).

## Notes

- Comments use giscus and are enabled per-post via `comments: true`, but
  live comments need the one-time giscus repo/category IDs filled into
  `_includes/giscus.html` (currently placeholders). Mention this once if
  relevant; it's outside this command's job.
- This command never edits already-published posts and never touches
  files other than the single new post (+ the promoted draft). For
  anything beyond that, tell me explicitly.
