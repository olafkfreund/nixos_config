# shellcheck shell=bash
guard_prepare() (
  set -o pipefail
  sed -e 's/&&/\n/g' -e 's/||/\n/g' -e 's/[;|]/\n/g' \
    | awk '
      {
        drop = 0
        if (index($0, "$(") == 0 && index($0, "`") == 0 &&
            index($0, "<(") == 0 && index($0, ">(") == 0 && index($0, "&") == 0) {
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
                       word == "-l" || word == "--list") { drop = 1; break }
              else if (word !~ /^-/) break
            }
          }
        }
        if (!drop) {
          gsub(/[\047"()`$]/, " ")
          print
        }
      }
    '
)
