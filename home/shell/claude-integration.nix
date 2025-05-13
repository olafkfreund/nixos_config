{
  lib,
  pkgs,
  config,
  ...
}: {
  options.programs.claudeCLI = {
    enable = lib.mkEnableOption "Claude CLI integration for ZSH";

    tempDir = lib.mkOption {
      type = lib.types.str;
      default = "/tmp";
      description = "Directory to store temporary files for Claude CLI";
      example = "$HOME/.cache/claude-cli";
    };

    terminals = lib.mkOption {
      type = lib.types.attrs;
      default = {
        kitty = "${pkgs.kitty}/bin/kitty";
        foot = "${pkgs.foot}/bin/foot";
      };
      description = "Terminal emulators for displaying Claude help results";
      example = ''
        {
          kitty = "''${pkgs.kitty}/bin/kitty";
          alacritty = "''${pkgs.alacritty}/bin/alacritty";
        }
      '';
    };

    keybindings = lib.mkOption {
      type = lib.types.attrs;
      default = {
        complete = {
          key = "\\ec"; # Alt+c
          altKey = "^X^C"; # Ctrl+X, Ctrl+C
        };
        help = {
          key = "\\eh"; # Alt+h
          altKey = "^X^H"; # Ctrl+X, Ctrl+H
        };
      };
      description = "Keybindings for Claude CLI functions";
      example = ''
        {
          complete.key = "\\ec";  # Alt+c
          help.key = "\\eh";  # Alt+h
        }
      '';
    };
  };

  config = lib.mkIf config.programs.claudeCLI.enable {
    home.packages = [pkgs.claude-cli];

    programs.zsh.initExtra = let
      cfg = config.programs.claudeCLI;
      tempDir = cfg.tempDir;
      terminals = cfg.terminals;
      keybindings = cfg.keybindings;
    in ''
            # Claude CLI Integration
            # ======================

            # Ensure required directories exist
            [[ -d "${tempDir}" ]] || mkdir -p "${tempDir}"

            # Claude code completion function
            _claude_code_complete() {
              # Safety checks
              if ! command -v ${pkgs.claude-cli}/bin/claude-cli &>/dev/null; then
                zle -M "Claude CLI not found. Please ensure it's installed."
                return 1
              fi

              local cursorPosition=$CURSOR
              local bufferText="''${BUFFER[1,$cursorPosition]}"
              local originalBuffer="$BUFFER"
              local promptFile="${tempDir}/claude_prompt_$$.txt"

              # Visual feedback during processing
              BUFFER="''${BUFFER[1,$cursorPosition]}… thinking …''${BUFFER[$cursorPosition+1,-1]}"
              zle -R

              # Save command to temporary file
              echo "$bufferText" > "$promptFile"

              # Get completion from Claude
              local completion
              completion=$(${pkgs.claude-cli}/bin/claude-cli complete -f "$promptFile" 2> "${tempDir}/claude_error_$$.log")
              local exitCode=$?

              # Handle the result
              if [[ $exitCode -eq 0 && -n "$completion" ]]; then
                BUFFER="''${bufferText}$completion''${originalBuffer[$cursorPosition+1,-1]}"
                CURSOR=$(( cursorPosition + ''${#completion} ))
              else
                BUFFER="$originalBuffer"
                if [[ -s "${tempDir}/claude_error_$$.log" ]]; then
                  zle -M "Claude completion failed: $(cat "${tempDir}/claude_error_$$.log")"
                else
                  zle -M "Claude completion failed (no response)"
                fi
              fi

              # Clean up temporary files
              rm -f "$promptFile" "${tempDir}/claude_error_$$.log"

              zle -R
            }

            # Claude help function
            _claude_code_help() {
              # Safety checks
              if ! command -v ${pkgs.claude-cli}/bin/claude-cli &>/dev/null; then
                zle -M "Claude CLI not found. Please ensure it's installed."
                return 1
              fi

              local bufferText="$BUFFER"
              local helpFile="${tempDir}/claude_help_$$.txt"
              local terminalCmd

              # Determine which terminal to use
              if [[ -n "$KITTY_WINDOW_ID" && -n "${terminals.kitty}" ]]; then
                terminalCmd="${terminals.kitty}"
              elif [[ -n "$FOOT_SERVER_PID" && -n "${terminals.foot}" ]]; then
                terminalCmd="${terminals.foot}"
              else
                # Default to first available terminal
                for term in ${builtins.concatStringsSep " " (builtins.attrNames terminals)}; do
                  if [[ -n "${terminals."$term"}" ]]; then
                    terminalCmd="${terminals."$term"}"
                    break
                  fi
                done
              fi

              if [[ -z "$terminalCmd" ]]; then
                zle -M "No suitable terminal found for displaying Claude help"
                return 1
              fi

              # Provide feedback
              zle -M "Opening Claude help for your command..."

              # Create help request with detailed context
              cat > "$helpFile" << EOT
      Help me understand and improve this shell command:
      \`\`\`bash
      $bufferText
      \`\`\`

      Please explain:
      1. What this command does
      2. Any potential issues or improvements
      3. Alternative approaches if relevant
      4. Security considerations if applicable
      EOT

              # Launch terminal with Claude results
              $terminalCmd --title "Claude Command Help" sh -c "${pkgs.claude-cli}/bin/claude-cli ask -f \"$helpFile\" | ${pkgs.less}/bin/less -R" &

              # Clean up temporary file after ensuring it's read
              (sleep 3 && rm -f "$helpFile") &>/dev/null &
            }

            # Register ZLE widgets
            zle -N _claude_code_complete
            zle -N _claude_code_help

            # Set up keybindings
            bindkey '${keybindings.complete.key}' _claude_code_complete
            bindkey '${keybindings.complete.altKey}' _claude_code_complete
            bindkey '${keybindings.help.key}' _claude_code_help
            bindkey '${keybindings.help.altKey}' _claude_code_help
    '';
  };
}
