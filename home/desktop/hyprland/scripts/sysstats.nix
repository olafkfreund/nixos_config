{pkgs, ...}:
pkgs.writeShellScriptBin "sysstats" ''
  # Function to check if an option is enabled
  is_enabled() {
    [[ "$1" == "true" ]]
  }

  # Get current stats
  get_cpu_stats() {
    if is_enabled "$cpu"; then
      mpstat -P ALL 1 1 | awk '
      BEGIN {
        print "┌──────────── CPU Stats ───────────┐"
      }
      NR > 3 {
        cpu = $2
        usr = $3
        sys = $5
        idle = $12
        if (idle < 99.99 || cpu == "all") {
          printf "│ 󰻠 CPU%-3s │ User: %5.1f%% Sys: %5.1f%% │\n", cpu, usr, sys
        }
      }
      END {
        print "└────────────────────────────────┘"
      }'
    fi
  }

  get_memory_stats() {
    if is_enabled "$memory"; then
      free -m | awk '
      BEGIN {
        print "┌──────────── Memory Stats ───────────┐"
      }
      NR == 2 {
        total = $2
        used = $3
        free = $4
        cached = $6
        printf "│  RAM │ Used: %5d MB Free: %5d MB │\n", used, free
        printf "│      │ Cache: %5d MB Total: %5d MB│\n", cached, total
      }
      END {
        print "└───────────────────────────────────┘"
      }'
    fi
  }

  get_disk_stats() {
    if is_enabled "$disk"; then
      df -h / /home 2>/dev/null | awk '
      BEGIN {
        print "┌──────────── Disk Stats ───────────┐"
      }
      NR > 1 {
        printf "│ 󰋊 %-6s│ Used: %4s Free: %4s │\n", $6, $3, $4
      }
      END {
        print "└───────────────────────────────────┘"
      }'
    fi
  }

  get_gpu_stats() {
    if is_enabled "$gpu"; then
      if command -v nvidia-smi &>/dev/null; then
        nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | awk -F',' '
        BEGIN {
          print "┌──────────── NVidia GPU Stats ───────────┐"
        }
        {
          printf "│ 󰢮 GPU │ Load: %3d%% Mem: %4d/%4d MB │\n", $1, $2, $3
        }
        END {
          print "└───────────────────────────────────┘"
        }'
      elif command -v rocm-smi &>/dev/null; then
        rocm-smi --showproductname --showgpuuse --showmemoryinfo | awk '
        BEGIN {
          print "┌──────────── AMD GPU Stats ───────────┐"
        }
        NR==2 {
          product_name = $2
        }
        /GPU use/ {
          gsub("GPU use: |%", "", $0)
          load = $0
        }
        /Memory total/ {
          gsub("Memory total: |\[|MiB|\]", "", $0)
          total_mem = $0
        }
        /Memory used/ {
          gsub("Memory used: |\[|MiB|\]", "", $0)
          used_mem = $0
          printf "│ 󰢮 GPU │ Load: %3d%% Mem: %4d/%4d MB │\n", load, used_mem, total_mem
        }
        END {
          print "└───────────────────────────────────┘"
        }'
      else
        echo "No supported GPU detected."
      fi
    fi
  }

  # Clear the screen
  clear

  # Default values
  cpu="true"
  memory="true"
  disk="true"
  gpu="true"

  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cpu)
        cpu="$2"
        shift
        ;;
      --memory)
        memory="$2"
        shift
        ;;
      --disk)
        disk="$2"
        shift
        ;;
      --gpu)
        gpu="$2"
        shift
        ;;
      *)
        echo "Unknown parameter passed: $1"
        exit 1
        ;;
    esac
    shift
  done

  # Print all stats based on options
  get_cpu_stats
  [[ "$cpu" == "true" ]] && echo
  get_memory_stats
  [[ "$memory" == "true" ]] && echo
  get_disk_stats
  [[ "$disk" == "true" ]] && echo
  get_gpu_stats
''
