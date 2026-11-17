# herdr-agent-plans: a herdr-app mod showing each agent's plan (#2978).
# One pin for both users: the herdr-app-sync source (home/development/herdr-app.nix)
# and the managed Claude/Codex hooks, which run this store copy of plan.py.
{ fetchFromGitHub }:
fetchFromGitHub {
  owner = "dendenlarin";
  repo = "herdr-agent-plans";
  rev = "8a4b42aa69649172d5c6b101a859edc9f4fbf33f";
  hash = "sha256-+quH9SPBlrV3LAw2DSdQV6IoPacOzFmhSOc2rzJGCus=";
}
