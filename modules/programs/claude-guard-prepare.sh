# shellcheck shell=bash
# Segments are split only to decide which to drop; kept ones are re-joined with their
# separators, padded with spaces, so the patterns still see a host and a verb across `&&`
# and a word right after `;` still starts a word (#3047 review).
guard_prepare() (
  set -o pipefail
  awk 'BEGIN { RS = "^$"; ORS = "" }
    {
      n = length($0); q = ""; out = ""
      for (k = 1; k <= n; k++) {
        c = substr($0, k, 1)
        if (q == "") {
          if (c == "\\") { out = out c (substr($0, k + 1, 1) ~ /[;&|\n]/ ? " " : substr($0, k + 1, 1)); k++; continue }
          if (c == "\047") { q = (substr($0, k - 1, 1) == "$") ? "a" : "s" }
          else if (c == "\"") q = "d"
          out = out c; continue
        }
        if (c == "\\" && q != "s") { out = out c (substr($0, k + 1, 1) ~ /[;&|\n]/ ? " " : substr($0, k + 1, 1)); k++; continue }
        if ((q == "s" || q == "a") && c == "\047") q = ""
        else if (q == "d" && c == "\"") q = ""
        if (c ~ /[;&|\n]/) c = " "
        out = out c
      }
      print out
    }' \
    | sed -e 's/&&/\n\x01A/g' -e 's/||/\n\x01O/g' -e 's/;/\n\x01S/g' -e 's/|/\n\x01P/g' \
    | awk '
      BEGIN {
        sep["A"] = "&&"; sep["O"] = "||"; sep["S"] = ";"; sep["P"] = "|"
        # Non-disruptive recipes with host arguments that main allows: none activates, collects garbage,
        # restarts or reboots (not all are read-only). Max args per recipe; checked by test-guard-safe-recipes.sh.
        safe["test-host"] = safe["diff"] = safe["secrets-status-host"] = safe["build-on-p620"] = safe["_sign-drv"] = 1
        safe["dry-run"] = safe["boot-space"] = safe["system-diff"] = safe["preview-updates"] = 1
        safe["update-commit"] = 2
      }
      {
        lead = ""
        if (substr($0, 1, 1) == "\001") { lead = " " sep[substr($0, 2, 1)] " "; $0 = substr($0, 3) }
        else if (out) printf "\n"
        drop = 0
        # Allow-list, not deny-list: a segment can only be a dry run if every character is
        # plain. Quotes, $, parentheses, backticks, backslashes, &, < and > can all hide a
        # command or move a word boundary that this split cannot see (#3047 reviews 1-4).
        if ($0 ~ /^[[:alnum:]_=.\/:,+[:blank:]-]*$/) {
          line = $0
          sub(/^[[:space:]]+/, "", line)
          sub(/[[:space:]]+$/, "", line)
          count = split(line, words, /[[:space:]]+/)
          i = 1
          while (i <= count && words[i] ~ /^[A-Za-z_][A-Za-z0-9_]*=/) i++
          if (words[i] == "just") {
            if (words[i + 1] in safe && count - (i + 1) <= safe[words[i + 1]]) {
              drop = 1
              for (j = i + 2; j <= count; j++) if (words[j] ~ /^-/) drop = 0
            }
            i++
            for (; i <= count; i++) {
              word = words[i]
              if ((word ~ /^--[a-z-]+=/ && word !~ /^--command=/) || word ~ /^-[fdEF]./) continue
              if (word == "-f" || word == "--justfile" ||
                  word == "-d" || word == "--working-directory") i++
              else if (word == "-n" || word == "--dry-run" ||
                       word == "-s" || word == "--show" ||
                       word == "-l" || word == "--list") {
                # An option after the flag may switch mode (--command runs despite -n): keep.
                drop = 1
                for (j = i + 1; j <= count; j++) if (words[j] ~ /^-/) drop = 0
                break
              }
              # Any other option may take a value that looks like -n (--shell-arg -n): keep.
              else break
            }
          }
        }
        printf "%s", lead; if (lead != "") out = 1
        if (!drop) {
          gsub(/[\047"]/, "")
          gsub(/[()`$]/, " ")
          printf "%s", $0; out = 1
        }
      }
      END { if (out) printf "\n" }
    '
)
