{pkgs, ...}:
pkgs.writeShellScriptBin "sysstats" ''
  # Get current stats
  get_cpu_stats() {
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
  }

  get_memory_stats() {
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
  }

  get_disk_stats() {
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
  }

  get_gpu_stats() {
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
      rocm-smi --showproductname --showbusy --showmemoryusage | awk '
      BEGIN {
        print "┌──────────── AMD GPU Stats ───────────┐"
      }
      NR==2 {
        product_name = $2
      }
      NR==3 {
        load = $2
      }
      NR==4 {
        memory_usage = $2
        gsub("\[|MiB|\]", "", memory_usage)
        split(memory_usage, mem_arr, "/")
        used_mem = mem_arr[1]
        total_mem = mem_arr[2]
        printf "│ 󰢮 GPU │ Load: %3d%% Mem: %4d/%4d MB │\n", load, used_mem, total_mem
      }
      END {
        print "└───────────────────────────────────┘"
      }'
    else
      echo "No supported GPU detected."
    fi
  }

  # Print all stats
  clear
  get_cpu_stats
  echo
  get_memory_stats
  echo
  get_disk_stats
  echo
  get_gpu_stats
''
