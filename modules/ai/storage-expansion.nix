# Storage Expansion and Optimization Recommendations
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.ai.storageExpansion;
in {
  options.ai.storageExpansion = {
    enable = mkEnableOption "Enable storage expansion analysis and recommendations";
    
    analysisMode = mkOption {
      type = types.enum [ "monitoring" "optimization" "expansion" ];
      default = "monitoring";
      description = "Storage analysis mode: monitoring, optimization, or expansion planning";
    };
    
    recommendationsPath = mkOption {
      type = types.str;
      default = "/var/lib/ai-analysis/storage-recommendations";
      description = "Path to store expansion recommendations";
    };
  };

  config = mkIf cfg.enable {
    # Storage expansion analysis service
    systemd.services.ai-storage-expansion = {
      description = "AI Storage Expansion Analysis";
      after = [ "network.target" ];
      wants = [ "network.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "ai-storage-expansion" ''
          #!/bin/bash
          
          # Configuration
          RECOMMENDATIONS_DIR="${cfg.recommendationsPath}"
          ANALYSIS_MODE="${cfg.analysisMode}"
          HOSTNAME=$(hostname)
          TIMESTAMP=$(date +%Y%m%d_%H%M%S)
          REPORT_FILE="$RECOMMENDATIONS_DIR/expansion_analysis_$HOSTNAME_$TIMESTAMP.json"
          LOG_FILE="/var/log/ai-analysis/storage-expansion.log"
          
          # Ensure directories exist
          mkdir -p "$RECOMMENDATIONS_DIR"
          mkdir -p "$(dirname "$LOG_FILE")"
          
          # Setup logging
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1
          
          echo "[$(date)] Starting storage expansion analysis for $HOSTNAME..."
          echo "[$(date)] Analysis mode: $ANALYSIS_MODE"
          
          # Function to analyze storage device
          analyze_device() {
            local device="$1"
            local mount_point="$2"
            local total_bytes="$3"
            local used_bytes="$4"
            local available_bytes="$5"
            local usage_percent="$6"
            
            # Calculate usage categories
            local usage_status="normal"
            if [ "$usage_percent" -gt 85 ]; then
              usage_status="critical"
            elif [ "$usage_percent" -gt 75 ]; then
              usage_status="warning"
            elif [ "$usage_percent" -gt 50 ]; then
              usage_status="moderate"
            fi
            
            # Determine device type and characteristics
            local device_type="unknown"
            local device_info=""
            
            if [[ "$device" == *"nvme"* ]]; then
              device_type="nvme_ssd"
              device_info="NVMe SSD - High performance, suitable for OS and applications"
            elif [[ "$device" == *"ssd"* ]] || [[ "$device" == *"sd"* ]] && lsblk -d -o name,rota | grep "$device" | grep -q "0"; then
              device_type="sata_ssd"
              device_info="SATA SSD - Good performance, suitable for data and applications"
            elif [[ "$device" == *"sd"* ]]; then
              device_type="hdd"
              device_info="Hard Disk Drive - High capacity, suitable for bulk storage"
            fi
            
            # Generate recommendations based on usage and type
            local recommendations=()
            
            case "$usage_status" in
              "critical")
                recommendations+=("URGENT: Immediate cleanup required")
                recommendations+=("Consider moving data to other volumes")
                recommendations+=("Implement aggressive cleanup automation")
                if [ "$device_type" = "hdd" ]; then
                  recommendations+=("Migrate critical data to SSD if available")
                fi
                ;;
              "warning")
                recommendations+=("Monitor closely and prepare cleanup")
                recommendations+=("Consider data archival or migration")
                recommendations+=("Schedule regular cleanup maintenance")
                ;;
              "moderate")
                recommendations+=("Normal monitoring sufficient")
                recommendations+=("Consider preventive cleanup scheduling")
                ;;
              "normal")
                recommendations+=("Good utilization level")
                recommendations+=("Continue normal monitoring")
                ;;
            esac
            
            # Storage-specific recommendations
            if [ "$mount_point" = "/" ]; then
              recommendations+=("Root filesystem - critical for system operation")
              recommendations+=("Keep Nix store optimized with regular garbage collection")
              if [ "$usage_percent" -gt 60 ]; then
                recommendations+=("Consider moving user data to separate volume")
              fi
            elif [ "$mount_point" = "/home" ]; then
              recommendations+=("Home directory - user data storage")
              recommendations+=("Implement user quota management if needed")
            elif [[ "$mount_point" == *"nix"* ]]; then
              recommendations+=("Nix store - optimize with nix-store --optimise")
              recommendations+=("Use nix-collect-garbage for cleanup")
            fi
            
            # Create device analysis object
            cat << EOF
            {
              "device": "$device",
              "mount_point": "$mount_point",
              "device_type": "$device_type",
              "device_info": "$device_info",
              "storage_metrics": {
                "total_bytes": $total_bytes,
                "used_bytes": $used_bytes,
                "available_bytes": $available_bytes,
                "usage_percent": $usage_percent,
                "total_human": "$(numfmt --to=iec-i --suffix=B $total_bytes 2>/dev/null || echo "$total_bytes bytes")",
                "used_human": "$(numfmt --to=iec-i --suffix=B $used_bytes 2>/dev/null || echo "$used_bytes bytes")",
                "available_human": "$(numfmt --to=iec-i --suffix=B $available_bytes 2>/dev/null || echo "$available_bytes bytes")"
              },
              "usage_status": "$usage_status",
              "recommendations": [
          $(printf '%s\n' "''${recommendations[@]}" | sed 's/.*/"&"/' | paste -sd, -)
              ]
            }
          EOF
          }
          
          # Collect filesystem information
          echo "[$(date)] Collecting filesystem information..."
          
          # Get detailed filesystem info
          FILESYSTEM_DATA=$(df -B1 --output=source,size,used,avail,pcent,target | tail -n +2)
          
          # Analyze each filesystem
          echo "[$(date)] Analyzing filesystems..."
          
          DEVICE_ANALYSES=""
          while IFS=' ' read -r source size used avail pcent target; do
            if [ -n "$source" ] && [ "$source" != "tmpfs" ] && [ "$source" != "devtmpfs" ] && [[ ! "$source" =~ ^/dev/loop ]]; then
              usage_num=$(echo "$pcent" | sed 's/%//')
              device_analysis=$(analyze_device "$source" "$target" "$size" "$used" "$avail" "$usage_num")
              
              if [ -n "$DEVICE_ANALYSES" ]; then
                DEVICE_ANALYSES="$DEVICE_ANALYSES,$device_analysis"
              else
                DEVICE_ANALYSES="$device_analysis"
              fi
            fi
          done <<< "$FILESYSTEM_DATA"
          
          # Analyze available block devices
          echo "[$(date)] Analyzing available block devices..."
          
          AVAILABLE_DEVICES=""
          if command -v lsblk &>/dev/null; then
            # Find unmounted or underutilized devices
            BLOCK_DEVICES=$(lsblk -J -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE | jq -r '.blockdevices[]? | select(.type=="disk") | .name')
            
            for device in $BLOCK_DEVICES; do
              device_path="/dev/$device"
              device_size=$(lsblk -b -d -o SIZE -n "$device_path" 2>/dev/null || echo "0")
              device_size_human=$(lsblk -d -o SIZE -n "$device_path" 2>/dev/null || echo "unknown")
              
              # Check if device has unmounted partitions
              unmounted_partitions=$(lsblk -J "$device_path" | jq -r '.blockdevices[]?.children[]? | select(.mountpoint == null) | .name' 2>/dev/null || echo "")
              
              if [ -n "$unmounted_partitions" ]; then
                for partition in $unmounted_partitions; do
                  partition_size=$(lsblk -b -o SIZE -n "/dev/$partition" 2>/dev/null || echo "0")
                  partition_size_human=$(lsblk -o SIZE -n "/dev/$partition" 2>/dev/null || echo "unknown")
                  
                  if [ "$partition_size" -gt 1073741824 ]; then # > 1GB
                    available_device_info='{
                      "device": "/dev/'$partition'",
                      "parent_device": "/dev/'$device'",
                      "size_bytes": '$partition_size',
                      "size_human": "'$partition_size_human'",
                      "status": "unmounted",
                      "potential_use": "Available for mounting or expansion"
                    }'
                    
                    if [ -n "$AVAILABLE_DEVICES" ]; then
                      AVAILABLE_DEVICES="$AVAILABLE_DEVICES,$available_device_info"
                    else
                      AVAILABLE_DEVICES="$available_device_info"
                    fi
                  fi
                done
              fi
            done
          fi
          
          # Generate P510-specific recommendations
          P510_RECOMMENDATIONS=""
          if [ "$HOSTNAME" = "p510" ]; then
            P510_RECOMMENDATIONS='{
              "critical_situation": {
                "root_filesystem_usage": "79.6%",
                "immediate_actions": [
                  "URGENT: Root filesystem at critical level",
                  "Execute emergency cleanup immediately",
                  "Move large files to /mnt/img_pool (5.1% used)",
                  "Consider /mnt/media migration (41% used, 11TB total)"
                ],
                "storage_reallocation": [
                  "Move Docker data to /mnt/img_pool",
                  "Relocate user data to /mnt/media",
                  "Use /mnt/img_pool for system backups",
                  "Consider /home relocation to separate volume"
                ],
                "nix_store_optimization": [
                  "Immediate: nix-collect-garbage -d --delete-older-than 6h",
                  "Implement: nix-store --optimise for deduplication",
                  "Schedule: Daily garbage collection for generations >24h",
                  "Monitor: Nix store growth patterns and size limits"
                ]
              },
              "expansion_strategy": {
                "short_term": [
                  "Utilize /mnt/img_pool (938GB, 5.1% used) for system expansion",
                  "Move non-critical data to /mnt/media (11TB capacity)",
                  "Implement bind mounts for /var/lib to /mnt/img_pool",
                  "Relocate Docker root to /mnt/img_pool"
                ],
                "medium_term": [
                  "Consider root filesystem expansion if possible",
                  "Implement LVM for flexible space management",
                  "Set up automated data tiering between volumes",
                  "Establish monitoring for all volume usage"
                ],
                "long_term": [
                  "Evaluate storage architecture redesign",
                  "Consider dedicated SSD for system + HDD for data",
                  "Implement automated data lifecycle management",
                  "Plan for future capacity growth"
                ]
              }
            }'
          fi
          
          # Generate comprehensive report
          cat > "$REPORT_FILE" << EOF
          {
            "analysis_metadata": {
              "hostname": "$HOSTNAME",
              "timestamp": "$(date -Iseconds)",
              "analysis_mode": "$ANALYSIS_MODE",
              "analyzer_version": "1.0"
            },
            "filesystem_analysis": [
              $DEVICE_ANALYSES
            ],
            "available_devices": [
              $AVAILABLE_DEVICES
            ],
            "system_recommendations": {
              "overall_health": "$([ $(df / | tail -1 | awk '{print $5}' | sed 's/%//') -gt 80 ] && echo "critical" || echo "healthy")",
              "priority_actions": [
                "Monitor critical filesystems closely",
                "Implement automated cleanup procedures",
                "Consider storage expansion for high-usage volumes",
                "Establish data lifecycle management policies"
              ],
              "optimization_opportunities": [
                "Nix store optimization and garbage collection",
                "Log rotation and cleanup automation", 
                "Docker image and volume cleanup",
                "Temporary file cleanup scheduling"
              ]
            }$([ "$HOSTNAME" = "p510" ] && echo ",$P510_RECOMMENDATIONS" || echo "")
          }
          EOF
          
          echo "[$(date)] Storage expansion analysis complete"
          echo "[$(date)] Report saved to: $REPORT_FILE"
          
          # Display summary for critical situations
          ROOT_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
          if [ "$ROOT_USAGE" -gt 75 ]; then
            echo "[$(date)] ⚠ WARNING: Root filesystem usage is $ROOT_USAGE%"
            if [ "$ROOT_USAGE" -gt 85 ]; then
              echo "[$(date)] 🚨 CRITICAL: Immediate action required!"
            fi
          fi
          
          echo "[$(date)] Storage expansion analysis completed successfully"
        '';
      };
    };

    # Timer for regular expansion analysis
    systemd.timers.ai-storage-expansion = {
      description = "AI Storage Expansion Analysis Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

    # Create directories for reports
    systemd.tmpfiles.rules = [
      "d ${cfg.recommendationsPath} 0755 ai-analysis ai-analysis -"
      "d /var/log/ai-analysis 0755 ai-analysis ai-analysis -"
    ];

    # Install required tools
    environment.systemPackages = with pkgs; [
      util-linux # lsblk, etc.
      jq
      coreutils
    ];
  };
}