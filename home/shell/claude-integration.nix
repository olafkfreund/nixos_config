{
  config,
  lib,
  pkgs,
  ...
}: {
  options.programs.claudeCode = {
    enable = lib.mkEnableOption "Claude Code integration for ZSH";

    tempDir = lib.mkOption {
      type = lib.types.str;
      default = "/tmp";
      description = "Directory to store temporary files for Claude Code";
      example = "$HOME/.cache/claude-code";
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
      description = "Keybindings for Claude Code functions";
      example = ''
        {
          complete.key = "\\ec";  # Alt+c
          help.key = "\\eh";  # Alt+h
        }
      '';
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "claude-4-sonnet-20250522";
      description = "Claude model to use for interactions";
      example = "claude-4-opus-20250522";
    };
  };

  config = lib.mkIf config.programs.claudeCode.enable {
    # home.packages = [pkgs.claude-code];

    programs.zsh.initContent = let
      cfg = config.programs.claudeCode;
      tempDir = cfg.tempDir;
      terminals = cfg.terminals;
      keybindings = cfg.keybindings;

      # Pre-generate the terminal selection logic to avoid shell expansion issues
      terminalSelectionScript =
        lib.concatMapStringsSep "\n"
        (term: ''[[ -z "$terminalCmd" && -n "${terminals.${term}}" ]] && terminalCmd="${terminals.${term}}"'')
        (builtins.attrNames terminals);
    in ''
      # Claude Code Integration
      # ======================

      # Ensure required directories exist
      [[ -d "${tempDir}" ]] || mkdir -p "${tempDir}"

      # Claude code completion function
      _claude_code_complete() {
        # Safety checks
        if ! command -v claude &>/dev/null; then
          zle -M "Claude executable not found. Please ensure claude-code is installed."
          return 1
        fi

        local cursorPosition=$CURSOR
        local bufferText="''${BUFFER[1,$cursorPosition]}"
        local originalBuffer="$BUFFER"
        local promptFile="${tempDir}/claude_prompt_$$.txt"

        # Visual feedback during processing
        BUFFER="''${BUFFER[1,$cursorPosition]}… thinking …''${BUFFER[$cursorPosition+1,-1]}"
        zle -R

        # Save prompt to temporary file with improved instructions
        cat > "$promptFile" << EOT
      # Task: Command/Code Completion
      You are helping complete a shell command or code snippet.

      ## Current input
      \`\`\`
      $bufferText
      \`\`\`

      ## Instructions
      1. Complete the command or code snippet above in a natural way
      2. Provide ONLY the completion text itself, no explanations
      3. If there are multiple possible completions, choose the most likely one
      4. Keep the same style and indentation as the input
      5. For shell commands, prefer concise but complete solutions
      EOT

        # Get completion from Claude using non-interactive mode
        local completion
        completion=$(claude --print "$(<$promptFile)" 2> "${tempDir}/claude_error_$$.log")
        local exitCode=$?

        # Handle the result
        if [[ $exitCode -eq 0 && -n "$completion" ]]; then
          # Extract just the completion, removing any explanatory text
          completion=$(echo "$completion" |
            sed -E '/^(```|I will|Here|The|This)/d' | # Remove common prefixes
            sed -E 's/^(\$|>) //' |                   # Remove shell prompt symbols
            sed '/./,$!d' |                           # Remove leading blank lines
            sed -e 's/^[[:space:]]*//' |              # Remove leading spaces
            sed -e 's/[[:space:]]*$//')               # Remove trailing spaces

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
        if ! command -v claude &>/dev/null; then
          zle -M "Claude executable not found. Please ensure claude-code is installed."
          return 1
        fi

        local bufferText="$BUFFER"
        local helpFile="${tempDir}/claude_help_$$.txt"
        local outFile="${tempDir}/claude_output_$$.txt"
        local terminalCmd=""

        # Skip if no command is present
        if [[ -z "$bufferText" ]]; then
          zle -M "No command to analyze. Please enter a command first."
          return 1
        fi

        # Determine which terminal to use
        if [[ -n "$KITTY_WINDOW_ID" && -n "${terminals.kitty}" ]]; then
          terminalCmd="${terminals.kitty}"
        elif [[ -n "$FOOT_SERVER_PID" && -n "${terminals.foot}" ]]; then
          terminalCmd="${terminals.foot}"
        else
          # Fall back to any available terminal - this section is pre-generated
          # to avoid shell expansion issues
          ${terminalSelectionScript}
        fi

        if [[ -z "$terminalCmd" ]]; then
          zle -M "No suitable terminal found for displaying Claude help"
          return 1
        fi

        # Provide feedback
        zle -M "Opening Claude help for your command..."

        # Create help request with detailed context for better analysis
        cat > "$helpFile" << EOT
      # Task: Shell Command Analysis

      Analyze this shell command:

      \`\`\`bash
      $bufferText
      \`\`\`

      ## Provide a detailed explanation including:

      1. **Command breakdown**: Explain each part of the command and what it does
      2. **Purpose**: What is this command designed to achieve?
      3. **Potential issues**: Are there any bugs, edge cases or security concerns?
      4. **Improvements**: How could this command be improved or made more robust?
      5. **Alternatives**: Are there better/alternative ways to achieve the same goal?
      6. **Examples**: If helpful, provide example use cases or variations

      Format your analysis with clear headings and concise explanations.
      EOT

        # Generate output first using the specified model
        claude --print "$(<$helpFile)" > "$outFile" 2>/dev/null

        # Launch terminal with Claude results - use terminal-specific commands
        if [[ "$terminalCmd" == *kitty* ]]; then
          $terminalCmd -T "Claude Command Analysis" sh -c "cat \"$outFile\" | ${pkgs.less}/bin/less -R" &
        elif [[ "$terminalCmd" == *foot* ]]; then
          $terminalCmd -T "Claude Command Analysis" sh -c "cat \"$outFile\" | ${pkgs.less}/bin/less -R" &
        elif [[ "$terminalCmd" == *alacritty* ]]; then
          $terminalCmd -t "Claude Command Analysis" -e sh -c "cat \"$outFile\" | ${pkgs.less}/bin/less -R" &
        elif [[ "$terminalCmd" == *wezterm* ]]; then
          $terminalCmd start --class "claude-help" -- sh -c "cat \"$outFile\" | ${pkgs.less}/bin/less -R" &
        elif [[ "$terminalCmd" == *ghost* || "$terminalCmd" == *ghostty* ]]; then
          $terminalCmd sh -c "cat \"$outFile\" | ${pkgs.less}/bin/less -R" &
        else
          # Generic fallback that should work with most terminals
          $terminalCmd sh -c "echo -e '\033[1;34mClaude Command Analysis\033[0m\n'; cat \"$outFile\" | ${pkgs.less}/bin/less -R" &
        fi

        # Clean up temporary files after ensuring they're read
        (sleep 5 && rm -f "$helpFile" "$outFile") &>/dev/null &
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
