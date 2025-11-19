{ config, lib, pkgs, ... }:

with lib;
let
  inherit (lib) types;
  cfg = config.programs.claude-monitor;

  # Create Python environment with dependencies
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    pytz
    requests
  ]);

  # Claude monitor script wrapper
  claude-monitor-script = pkgs.writeShellScriptBin "claude-monitor" ''
    #!/usr/bin/env bash
    # Claude Code Usage Monitor

    set -euo pipefail

    PLAN="${cfg.plan}"
    RESET_HOUR="${toString cfg.resetHour}"
    TIMEZONE="${cfg.timezone}"

    # Check if ccusage is installed globally
    if ! command -v ccusage &> /dev/null; then
      echo "Error: ccusage npm package not found"
      echo "Installing ccusage..."
      ${pkgs.nodejs}/bin/npm install -g ccusage
    fi

    # Build command with options
    CMD="${pythonEnv}/bin/python3 $HOME/.local/share/claude-monitor/ccusage_monitor.py"
    CMD="$CMD --plan $PLAN"
    CMD="$CMD --reset-hour $RESET_HOUR"
    CMD="$CMD --timezone $TIMEZONE"

    # Add verbose flag if requested
    ${if cfg.verbose then ''CMD="$CMD --verbose"'' else ""}

    exec $CMD "$@"
  '';

  # The actual Python monitor script
  monitorPythonScript = pkgs.writeText "ccusage_monitor.py" ''
    #!/usr/bin/env python3
    """
    Claude Code Usage Monitor
    Real-time token usage tracking for Claude Code
    """

    import subprocess
    import json
    import sys
    import time
    import argparse
    from datetime import datetime, timedelta
    try:
        import pytz
    except ImportError:
        print("Error: pytz module not found. Install with: pip install pytz")
        sys.exit(1)

    # ANSI color codes
    class Colors:
        GREEN = '\033[92m'
        YELLOW = '\033[93m'
        RED = '\033[91m'
        BLUE = '\033[94m'
        BOLD = '\033[1m'
        END = '\033[0m'

    # Plan limits (tokens)
    PLANS = {
        'pro': 7000,
        'max5': 35000,
        'max20': 140000,
        'custom_max': None  # Auto-detect
    }

    def get_usage_data():
        """Fetch current usage data from ccusage"""
        try:
            result = subprocess.run(
                ['ccusage', '--json'],
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode == 0:
                return json.loads(result.stdout)
            return None
        except (subprocess.TimeoutExpired, json.JSONDecodeError, FileNotFoundError):
            return None

    def calculate_progress(used, limit):
        """Calculate usage percentage"""
        if limit is None or limit == 0:
            return 0
        return min(100, (used / limit) * 100)

    def get_progress_bar(percentage, width=50):
        """Generate colored progress bar"""
        filled = int(width * percentage / 100)
        bar = '█' * filled + '░' * (width - filled)

        if percentage < 50:
            color = Colors.GREEN
        elif percentage < 80:
            color = Colors.YELLOW
        else:
            color = Colors.RED

        return f"{color}{bar}{Colors.END}"

    def format_tokens(tokens):
        """Format token count with separators"""
        return f"{tokens:,}"

    def calculate_burn_rate(usage_history):
        """Calculate token burn rate (tokens/hour)"""
        if len(usage_history) < 2:
            return 0

        time_diff = usage_history[-1]['time'] - usage_history[0]['time']
        token_diff = usage_history[-1]['used'] - usage_history[0]['used']

        if time_diff == 0:
            return 0

        return (token_diff / time_diff) * 3600  # Convert to per hour

    def time_until_reset(reset_hour, timezone_str):
        """Calculate time until next reset"""
        tz = pytz.timezone(timezone_str)
        now = datetime.now(tz)

        next_reset = now.replace(hour=reset_hour, minute=0, second=0, microsecond=0)
        if now.hour >= reset_hour:
            next_reset += timedelta(days=1)

        delta = next_reset - now
        hours = int(delta.total_seconds() // 3600)
        minutes = int((delta.total_seconds() % 3600) // 60)

        return hours, minutes

    def monitor_usage(plan='pro', reset_hour=0, timezone='UTC', verbose=False):
        """Main monitoring loop"""
        limit = PLANS.get(plan)
        usage_history = []

        print(f"{Colors.BOLD}Claude Code Usage Monitor{Colors.END}")
        print(f"Plan: {plan.upper()}")
        if limit:
            print(f"Limit: {format_tokens(limit)} tokens")
        print(f"Reset: {reset_hour:02d}:00 {timezone}")
        print("─" * 70)

        try:
            while True:
                data = get_usage_data()

                if data is None:
                    print(f"{Colors.RED}Unable to fetch usage data{Colors.END}")
                    time.sleep(5)
                    continue

                used = data.get('tokens_used', 0)
                current_limit = limit if limit else used * 1.2  # Auto-detect limit

                # Update history
                usage_history.append({
                    'time': time.time(),
                    'used': used
                })
                # Keep only last hour of history
                cutoff_time = time.time() - 3600
                usage_history = [h for h in usage_history if h['time'] > cutoff_time]

                # Calculate metrics
                percentage = calculate_progress(used, current_limit)
                burn_rate = calculate_burn_rate(usage_history)
                hours_to_reset, mins_to_reset = time_until_reset(reset_hour, timezone)

                # Display
                print(f"\r{Colors.BOLD}Usage:{Colors.END} {format_tokens(used)}/{format_tokens(int(current_limit))} ", end='')
  print(f"[{percentage:.1f}%]", end='')

                if burn_rate > 0:
                    time_until_limit = ((current_limit - used) / burn_rate) * 60  # minutes
                    print(f" | {Colors.BLUE}Burn: {burn_rate:.0f} tok/hr{Colors.END}", end='')
  if time_until_limit > 0 and time_until_limit < 300:  # Less than 5 hours
  print(f" | {Colors.RED}⚠ {time_until_limit:.0f}min until limit{Colors.END}", end='')

                print(f" | Reset in: {hours_to_reset}h {mins_to_reset}m", end='', flush=True)

  if verbose:
  print()  # New line for verbose output
  print(get_progress_bar(percentage))

  time.sleep(3)

  except KeyboardInterrupt:
  print(f"\n{Colors.BOLD}Monitoring stopped{Colors.END}")
  sys.exit(0)

  def main():
  parser = argparse.ArgumentParser(description='Claude Code Usage Monitor')
  parser.add_argument('--plan', choices=list(PLANS.keys()), default='pro',
  help='Claude Code plan type')
  parser.add_argument('--reset-hour', type=int, default=0,
  help='Hour when usage resets (0-23)')
  parser.add_argument('--timezone', default='UTC',
  help='Timezone for reset time')
  parser.add_argument('--verbose', action='store_true',
  help='Show detailed output with progress bar')

  args = parser.parse_args()

  monitor_usage(
  plan=args.plan,
  reset_hour=args.reset_hour,
  timezone=args.timezone,
  verbose=args.verbose
  )

  if __name__ == '__main__':
  main()
  '';

in
{
  options.programs.claude-monitor = {
    enable = mkEnableOption "Claude Code Usage Monitor";

    package = mkOption {
      type = types.package;
      default = claude-monitor-script;
      description = "The claude-monitor package to use";
    };

    plan = mkOption {
      type = types.enum [ "pro" "max5" "max20" "custom_max" ];
      default = "pro";
      description = "Claude Code plan type";
      example = "max5";
    };

    resetHour = mkOption {
      type = types.ints.between 0 23;
      default = 0;
      description = "Hour when usage resets (0-23, in your timezone)";
      example = 9;
    };

    timezone = mkOption {
      type = types.str;
      default = "UTC";
      description = "Timezone for reset time";
      example = "US/Eastern";
    };

    verbose = mkOption {
      type = types.bool;
      default = false;
      description = "Show detailed output with progress bar";
    };

    enableService = mkOption {
      type = types.bool;
      default = false;
      description = "Run as systemd user service for continuous monitoring";
    };

    shellAliases = mkOption {
      type = types.attrsOf types.str;
      default = {
        claude-usage = "claude-monitor";
        ccusage-monitor = "claude-monitor";
      };
      description = "Shell aliases for claude-monitor";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      cfg.package
      pythonEnv
      pkgs.nodejs  # For npm global installs
    ];

    # Install monitor script
    home.file.".local/share/claude-monitor/ccusage_monitor.py" = {
      source = monitorPythonScript;
    };

    # Install ccusage npm package globally on activation
    home.activation.installCcusage = lib.hm.dag.entryAfter ["writeBoundary"] ''
  if ! command -v ccusage &> /dev/null;
  then
  $DRY_RUN_CMD ${pkgs.nodejs}/bin/npm install -g ccusage || echo "Warning: Failed to install ccusage"
  fi
  '';

    # Shell aliases
    programs.zsh.shellAliases = mkIf config.programs.zsh.enable cfg.shellAliases;
    programs.bash.shellAliases = mkIf config.programs.bash.enable cfg.shellAliases;
    programs.fish.shellAliases = mkIf config.programs.fish.enable cfg.shellAliases;

    # Optional: Systemd service for continuous monitoring
    systemd.user.services.claude-monitor = mkIf cfg.enableService {
      Unit = {
        Description = "Claude Code Usage Monitor";
        After = [ "network.target" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/claude-monitor";
        Restart = "on-failure";
        RestartSec = "10s";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    # Helper script for quick status check
    home.file.".local/bin/claude-usage-check" = {
      text = ''
  #!/usr/bin/env bash
  # Quick usage check without continuous monitoring

  if command -v ccusage &> /dev/null; then
  ${pkgs.nodejs}/bin/npx ccusage
  else
  echo "Error: ccusage not installed"
  echo "Enable claude-monitor to install it automatically"
  exit 1
  fi
  ''   ;
      executable = true;
    };

    # Development environment integration
    home.sessionPath = [ "$HOME/.local/bin" ];
  };
}
