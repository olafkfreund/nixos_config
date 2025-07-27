#!/usr/bin/env bash

# Simple Temperature Dashboard for waybar
# Shows CPU, GPU, and NVMe temperatures using yad

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
        echo "scale=1; $temp_millicelsius / 1000" | bc
    else
        echo "N/A"
    fi
}

get_gpu_temp() {
    # Try AMD GPU first via hwmon
    for hwmon in /sys/class/hwmon/hwmon*/; do
        if [[ -f "$hwmon/name" ]]; then
            local name=$(cat "$hwmon/name")
            if [[ "$name" == "amdgpu" ]]; then
                if [[ -f "$hwmon/temp1_input" ]]; then
                    local temp_millicelsius=$(cat "$hwmon/temp1_input")
                    echo "scale=1; $temp_millicelsius / 1000" | bc
                    return
                fi
            fi
        fi
    done
    
    echo "N/A"
}

get_nvme_temp() {
    # Try hwmon for nvme
    for hwmon in /sys/class/hwmon/hwmon*/; do
        if [[ -f "$hwmon/name" ]]; then
            local name=$(cat "$hwmon/name")
            if [[ "$name" == "nvme" ]]; then
                if [[ -f "$hwmon/temp1_input" ]]; then
                    local temp_millicelsius=$(cat "$hwmon/temp1_input")
                    echo "scale=1; $temp_millicelsius / 1000" | bc
                    return
                fi
            fi
        fi
    done
    
    echo "N/A"
}

get_temp_color() {
    local temp=$1
    if [[ "$temp" == "N/A" ]]; then
        echo "#ebdbb2"  # Default color
    elif (( $(echo "$temp < 50" | bc -l) )); then
        echo "#8ec07c"  # Good (green)
    elif (( $(echo "$temp < 70" | bc -l) )); then
        echo "#fabd2f"  # Warning (yellow)
    else
        echo "#fb4934"  # Critical (red)
    fi
}

format_temp() {
    local temp=$1
    if [[ "$temp" == "N/A" ]]; then
        echo "$temp"
    else
        echo "${temp}°C"
    fi
}

# Get temperatures
cpu_temp=$(get_cpu_temp)
gpu_temp=$(get_gpu_temp)
nvme_temp=$(get_nvme_temp)

# Format temperatures
cpu_display=$(format_temp "$cpu_temp")
gpu_display=$(format_temp "$gpu_temp")
nvme_display=$(format_temp "$nvme_temp")

# Get colors
cpu_color=$(get_temp_color "$cpu_temp")
gpu_color=$(get_temp_color "$gpu_temp")
nvme_color=$(get_temp_color "$nvme_temp")

# Create YAD dialog
yad \
    --title="System Temperature Dashboard" \
    --width=400 \
    --height=300 \
    --center \
    --on-top \
    --no-buttons \
    --timeout=30 \
    --timeout-indicator=bottom \
    --text-align=center \
    --fontname="JetBrainsMono Nerd Font 12" \
    --fore="#ebdbb2" \
    --back="#282828" \
    --text="<big><b>🌡️ System Temperatures</b></big>

<span font='JetBrainsMono Nerd Font 16' foreground='$cpu_color'><b>🔥 CPU: $cpu_display</b></span>

<span font='JetBrainsMono Nerd Font 16' foreground='$gpu_color'><b>🎮 GPU: $gpu_display</b></span>

<span font='JetBrainsMono Nerd Font 16' foreground='$nvme_color'><b>💾 NVMe: $nvme_display</b></span>

<small><i>Auto-closes in 30 seconds</i></small>"