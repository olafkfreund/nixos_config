{pkgs, ...}:
pkgs.writeShellScriptBin "cpustats" ''
  mpstat -P ALL 1 1 | awk '
    BEGIN {
        # Define CPU symbols
        symbols["CPU"] = " "
        symbols["all"] = "∑"
    }
    {
        if (NR > 3) {  # Skip header lines
            # Get CPU identifier
            cpu = $2
            # Get CPU utilization
            usr = $3
            sys = $5

            # Add appropriate symbol
            if (cpu == "all") {
                symbol = symbols["all"]
            } else {
                symbol = symbols["CPU"]
            }

            # Format and print with colors and symbols
            printf "%s CPU%-3s | User: \033[33m%6.2f%%\033[0m | Sys: \033[36m%6.2f%%\033[0m | Idle: \033[32m%6.2f%%\033[0m\n",
                symbol, cpu, usr, sys
        }
    }
  }'
''
