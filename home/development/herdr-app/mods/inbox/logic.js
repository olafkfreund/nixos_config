const GH_FIELDS = ["--state=open", "--limit", "100", "--json", "repository,number,title,url,updatedAt"];

export function queries(username) {
  const gh = [
    ...["assignee", "author"].map(reason => ({ provider: "GitHub", kind: "issue", reason, cmd: "gh", args: ["search", "issues", `--${reason}=@me`, ...GH_FIELDS] })),
    ...["assignee", "author", "review-requested"].map(reason => ({ provider: "GitHub", kind: "pr", reason, cmd: "gh", args: ["search", "prs", `--${reason}=@me`, ...GH_FIELDS] })),
  ];
  const gl = [
    ...["assigned_to_me", "created_by_me"].map(scope => ({ provider: "GitLab", kind: "issue", reason: scope === "assigned_to_me" ? "assignee" : "author", endpoint: `issues?scope=${scope}&state=opened&per_page=100` })),
    ...["assigned_to_me", "created_by_me"].map(scope => ({ provider: "GitLab", kind: "mr", reason: scope === "assigned_to_me" ? "assignee" : "author", endpoint: `merge_requests?scope=${scope}&state=opened&per_page=100` })),
    { provider: "GitLab", kind: "mr", reason: "review-requested", endpoint: `merge_requests?scope=all&reviewer_username=${encodeURIComponent(username)}&state=opened&per_page=100` },
  ];
  return [...gh, ...gl];
}

export function parseItems(query, output) {
  const items = JSON.parse(output || "[]");
  if (!Array.isArray(items)) throw new Error("Expected a JSON array");
  return items.map(item => {
    const repo = query.provider === "GitHub" ? item.repository?.nameWithOwner : item.references?.full?.split(query.kind === "mr" ? "!" : "#")[0];
    const number = query.provider === "GitHub" ? item.number : item.iid;
    if (!repo || !number || !(item.url || item.web_url)) throw new Error("Item has no repository, number or URL");
    const sigil = query.kind === "mr" ? "!" : "#";
    return { id: `${query.provider === "GitHub" ? "gh" : "gl"}:${repo}${sigil}${number}`, provider: query.provider, kind: query.kind, repo, number,
      title: item.title, url: item.url || item.web_url, updated: item.updatedAt || item.updated_at, reasons: [query.reason] };
  });
}

export const capLine = capped => capped ? "showing 100 of more, open on the web" : "";

export function merge(results) {
  const rows = new Map(), errors = {}, capped = new Set();
  for (const result of results) {
    if (result.error) { errors[result.query.provider] = result.error; continue; }
    if (result.capped) capped.add(result.query.provider);
    for (const item of result.items) {
      const old = rows.get(item.id);
      if (old) { if (!old.reasons.includes(result.query.reason)) old.reasons.push(result.query.reason); }
      else rows.set(item.id, { ...item, reasons: [...item.reasons] });
    }
  }
  return { rows: [...rows.values()].sort((a, b) => (b.updated || "").localeCompare(a.updated || "")), errors, capped: [...capped] };
}

export async function fetchInbox(exec) {
  let username;
  let gitlabError;
  try {
    const user = await exec("glab", ["api", "--hostname", "gitlab.com", "user"]);
    if (user.code !== 0) throw new Error(user.stderr || "glab api user failed");
    username = JSON.parse(user.stdout).username;
    if (!username) throw new Error("GitLab username missing");
  } catch (e) { gitlabError = String(e); }
  const results = await Promise.all(queries(username || "").map(async query => {
    if (query.provider === "GitLab" && gitlabError) return { query, error: gitlabError };
    try {
      if (query.provider === "GitHub") {
        const r = await exec(query.cmd, query.args);
        if (r.code !== 0) throw new Error(r.stderr || "gh search failed");
        const items = parseItems(query, r.stdout);
        return { query, items, capped: items.length >= 100 };
      }
      let items = [];
      for (let page = 1; page <= 3; page++) {
        const r = await exec("glab", ["api", "--hostname", "gitlab.com", `${query.endpoint}&page=${page}`]);
        if (r.code !== 0) throw new Error(r.stderr || "glab api failed");
        const batch = parseItems(query, r.stdout);
        items.push(...batch);
        if (batch.length < 100 || items.length > 100) break;
      }
      return { query, items: items.slice(0, 100), capped: items.length > 100 };
    } catch (e) { return { query, error: String(e) }; }
  }));
  return merge(results);
}
