{pkgs, ...}:
pkgs.writeShellScriptBin "cpustats" ''
  mpstat -P ALL 1 1 | awk '
  BEGIN {
      # Define CPU symbols
      symbols["CPU"] = ""
      symbols["all"] = "∑"
  }
  {
      if (NR > 3) {  # Skip header lines
          # Get CPU identifier
          cpu = $2
          # Get CPU utilization
          usr = $3
          sys = $5
          idle = $12

          # Only show CPUs with activity
          if (idle < 99.99 || cpu == "all") {
              # Add appropriate symbol
              if (cpu == "all") {
                  symbol = symbols["all"]
              } else {
                  symbol = symbols["CPU"]
              }

              # Format and print with symbols (without idle)
              printf "%s CPU%-3s\nUser: %6.2f%%\nSys:  %6.2f%%\n--------------\n",
                  symbol, cpu, usr, sys
          }
      }
  }'
''
