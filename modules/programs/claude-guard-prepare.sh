# shellcheck shell=bash
# Segments are split only to decide which to drop; kept ones are re-joined with their
# separators, padded with spaces, so the patterns still see a host and a verb across `&&`
# and a word right after `;` still starts a word (#3047 review).
guard_prepare() (
  set -o pipefail
  sed -e 's/&&/\n\x01A/g' -e 's/||/\n\x01O/g' -e 's/;/\n\x01S/g' -e 's/|/\n\x01P/g' \
    | awk '
      BEGIN { sep["A"] = "&&"; sep["O"] = "||"; sep["S"] = ";"; sep["P"] = "|" }
      {
        lead = ""
        if (substr($0, 1, 1) == "\001") { lead = " " sep[substr($0, 2, 1)] " "; $0 = substr($0, 3) }
        else if (out) printf "\n"
        drop = 0
        if (index($0, "$(") == 0 && index($0, "`") == 0 &&
            index($0, "<(") == 0 && index($0, ">(") == 0 && index($0, "&") == 0 &&
            # Quotes and backslashes change word boundaries that this split cannot see.
            index($0, "\047") == 0 && index($0, "\"") == 0 && index($0, "\\") == 0) {
          line = $0
          sub(/^[[:space:]]+/, "", line)
          count = split(line, words, /[[:space:]]+/)
          i = 1
          while (i <= count && words[i] ~ /^[A-Za-z_][A-Za-z0-9_]*=/) i++
          if (words[i++] == "just") {
            for (; i <= count; i++) {
              word = words[i]
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
