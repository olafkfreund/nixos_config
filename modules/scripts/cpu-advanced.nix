{ config
, lib
, pkgs
, ...
}:
with lib; let
  # Advanced CPU monitoring script for Waybar with comprehensive system information
  cpuAdvanced = pkgs.writeShellScriptBin "cpu-advanced" ''
    #!/usr/bin/env bash

    # Advanced CPU monitoring for Waybar
    # Outputs JSON with comprehensive system information

    get_cpu_usage() {
        ${pkgs.procps}/bin/top -bn1 | grep "Cpu(s)" | \
            sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | \
            ${pkgs.gawk}/bin/awk '{print 100 - $1}'
    }

    get_cpu_frequency() {
        local avg_freq=$(${pkgs.gawk}/bin/awk '/cpu MHz/ {sum += $4; count++} END {if (count > 0) print sum/count/1000; else print "0"}' /proc/cpuinfo)
        local max_freq=$(${pkgs.gawk}/bin/awk '/cpu MHz/ {if ($4 > max) max = $4} END {print max/1000}' /proc/cpuinfo)
        local min_freq=$(${pkgs.gawk}/bin/awk 'BEGIN {min = 999999} /cpu MHz/ {if ($4 < min) min = $4} END {print min/1000}' /proc/cpuinfo)

        echo "$avg_freq $max_freq $min_freq"
    }

    get_load_average() {
        ${pkgs.gawk}/bin/awk '{print $1, $2, $3}' /proc/loadavg
    }

    get_cpu_temp() {
        local temp_path=""

        # Look for k10temp (AMD) or coretemp (Intel)
        for hwmon in /sys/class/hwmon/hwmon*/; do
            if [[ -f "$hwmon/name" ]]; then
                local name=$(cat "$hwmon/name")
                if [[ "$name" == "k10temp" || "$name" == "coretemp" ]]; then
                    if [[ -f "$hwmon/temp1_input" ]]; then
                        temp_path="$hwmon/temp1_input"
                        break
                    fi
                fi
            fi
        done

        if [[ -n "$temp_path" && -f "$temp_path" ]]; then
            local temp_millicelsius=$(cat "$temp_path")
            echo "scale=1; $temp_millicelsius / 1000" | ${pkgs.bc}/bin/bc
        else
            echo "N/A"
        fi
    }

    get_per_core_usage() {
        # Get per-core usage from /proc/stat
        local cores_info=""
        local core_count=0

        while IFS= read -r line; do
            if [[ $line =~ ^cpu[0-9]+ ]]; then
                local core_num=$(echo "$line" | ${pkgs.gawk}/bin/awk '{print $1}' | sed 's/cpu//')
                local usage=$(echo "$line" | ${pkgs.gawk}/bin/awk '{
                    idle = $5
                    total = $2 + $3 + $4 + $5 + $6 + $7 + $8
                    usage = 100 - (idle / total * 100)
                    printf "%.0f", usage
                }')

                # Get frequency for this core if available
                local freq_file="/sys/devices/system/cpu/cpu$core_num/cpufreq/scaling_cur_freq"
                local freq="N/A"
                if [[ -f "$freq_file" ]]; then
                    local freq_khz=$(cat "$freq_file")
                    freq=$(echo "scale=1; $freq_khz / 1000000" | ${pkgs.bc}/bin/bc)
                fi

                cores_info+="  ├ Core $core_num: $usage%"
                if [[ "$freq" != "N/A" ]]; then
                    cores_info+=" @ ''${freq}GHz"
                fi
                cores_info+="\n"
                ((core_count++))
            fi
        done < /proc/stat

        # Fix the last core to use └ instead of ├
        if [[ $core_count -gt 0 ]]; then
            cores_info=$(echo -e "$cores_info" | sed '$s/├/└/')
        fi

        echo -e "$cores_info"
    }

    get_process_count() {
        local total=$(${pkgs.procps}/bin/ps ax | wc -l)
        local running=$(${pkgs.procps}/bin/ps axo stat | grep -c "^R")
        echo "$total $running"
    }

    get_cpu_model() {
        ${pkgs.gawk}/bin/awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo
    }

    get_cpu_cores() {
        ${pkgs.coreutils}/bin/nproc
    }

    get_uptime() {
        local uptime_seconds=$(${pkgs.gawk}/bin/awk '{print int($1)}' /proc/uptime)
        local days=$((uptime_seconds / 86400))
        local hours=$(( (uptime_seconds % 86400) / 3600 ))
        local minutes=$(( (uptime_seconds % 3600) / 60 ))

        if [[ $days -gt 0 ]]; then
            echo "''${days}d ''${hours}h ''${minutes}m"
        elif [[ $hours -gt 0 ]]; then
            echo "''${hours}h ''${minutes}m"
        else
            echo "''${minutes}m"
        fi
    }

    # Collect all data
    cpu_usage=$(get_cpu_usage)
    cpu_usage_int=$(echo "$cpu_usage" | ${pkgs.gawk}/bin/awk '{printf "%.0f", $1}')
    read avg_freq max_freq min_freq <<< $(get_cpu_frequency)
    read load1 load5 load15 <<< $(get_load_average)
    cpu_temp=$(get_cpu_temp)
    per_core_usage=$(get_per_core_usage)
    read total_processes running_processes <<< $(get_process_count)
    cpu_model=$(get_cpu_model)
    cpu_cores=$(get_cpu_cores)
    uptime=$(get_uptime)

    # Format frequency display
    if [[ "$avg_freq" != "0" && "$avg_freq" != "" ]]; then
        freq_display=$(printf "%.1fGHz" "$avg_freq")
        main_text=" $cpu_usage_int% @ $freq_display"
    else
        main_text=" $cpu_usage_int%"
    fi

    # Determine status class based on usage
    if [[ $cpu_usage_int -lt 30 ]]; then
        status_class="low"
    elif [[ $cpu_usage_int -lt 70 ]]; then
        status_class="normal"
    elif [[ $cpu_usage_int -lt 90 ]]; then
        status_class="warning"
    else
        status_class="critical"
    fi

    # Build comprehensive tooltip
    tooltip="CPU Details:\\n"
    tooltip+="• Model: $cpu_model\\n"
    tooltip+="• Cores: $cpu_cores physical cores\\n"
    tooltip+="• Usage: $cpu_usage_int% (''${cpu_cores} cores active)\\n"

    if [[ "$avg_freq" != "0" && "$avg_freq" != "" ]]; then
        tooltip+="• Frequency: $(printf "%.1f" "$avg_freq")GHz (avg) | $(printf "%.1f" "$max_freq")GHz (max) | $(printf "%.1f" "$min_freq")GHz (min)\\n"
    fi

    tooltip+="• Load Average: $load1, $load5, $load15\\n"

    if [[ "$cpu_temp" != "N/A" ]]; then
        tooltip+="• Temperature: ''${cpu_temp}°C\\n"
    fi

    tooltip+="• Uptime: $uptime\\n"
    tooltip+="• Per-Core Usage:\\n"
    tooltip+="$(echo -e "$per_core_usage")"
    tooltip+="• Process Count: $total_processes total | $running_processes running"

    # Output JSON for Waybar
    ${pkgs.jq}/bin/jq -n \
        --arg text "$main_text" \
        --arg tooltip "$tooltip" \
        --arg class "$status_class" \
        --argjson percentage "$cpu_usage_int" \
        '{
            text: $text,
            tooltip: $tooltip,
            class: $class,
            percentage: $percentage
        }'
  '';
in
{
  options.scripts.cpuAdvanced = {
    enable = mkEnableOption "Advanced CPU monitoring script for Waybar";
  };

  config = mkIf config.scripts.cpuAdvanced.enable {
    environment.systemPackages = with pkgs; [
      cpuAdvanced
      procps
      gawk
      bc
      jq
      coreutils
    ];
  };
}
