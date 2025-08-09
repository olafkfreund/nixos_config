{ pkgs, ... }:
pkgs.writeShellScriptBin "fzf-preview" ''
  if [[ $# -ne 1 ]]; then
    >&2 echo "usage: $0 FILENAME"
    exit 1
  fi

  file=''${1/#\~\//$HOME/}
  type=$(file --dereference --mime -- "$file")

  if [[ ! $type =~ image/ ]]; then
    if [[ $type =~ =binary ]]; then
      file "$1"
      exit
    fi

    # Sometimes bat is installed as batcat.
    if command -v batcat > /dev/null; then
      batname="batcat"
    elif command -v bat > /dev/null; then
      batname="bat"
    else
      cat "$1"
      exit
    fi

    ''${batname} --style="''${BAT_STYLE:-numbers}" --color=always --pager=never -- "$file"
    exit
  fi

  dim=''${FZF_PREVIEW_COLUMNS}x''${FZF_PREVIEW_LINES}
  if [[ $dim = x ]]; then
    dim=$(stty size < /dev/tty | awk '{print $2 "x" $1}')
  elif ! [[ $KITTY_WINDOW_ID ]] && (( FZF_PREVIEW_TOP + FZF_PREVIEW_LINES == $(stty size < /dev/tty | awk '{print $1}') )); then
    dim=''${FZF_PREVIEW_COLUMNS}x$((FZF_PREVIEW_LINES - 1))
  fi

  # 1. Use kitty icat on kitty terminal
  if [[ $KITTY_WINDOW_ID ]]; then
    kitty icat --clear --transfer-mode=memory --unicode-placeholder --stdin=no --place="$dim@0x0" "$file" | sed '$d' | sed $'$s/$/\e[m/'

  # 2. Use chafa with Sixel output
  elif command -v chafa > /dev/null; then
    chafa -f sixel -s "$dim" "$file"
    echo

  # 3. If chafa is not found but imgcat is available, use it on iTerm2
  elif command -v imgcat > /dev/null; then
    imgcat -W "''${dim%%x*}" -H "''${dim##*x}" "$file"

  # 4. Cannot find any suitable method to preview the image
  else
    file "$file"
  fi
''
