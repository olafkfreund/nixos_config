# AI-Powered Security Audit and Hardening System
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.ai.securityAudit;
in {
  options.ai.securityAudit = {
    enable = mkEnableOption "Enable AI-powered security audit and hardening";
    
    auditLevel = mkOption {
      type = types.enum [ "basic" "comprehensive" "advanced" ];
      default = "basic";
      description = "Security audit level: basic, comprehensive, or advanced";
    };
    
    autoHardening = mkOption {
      type = types.bool;
      default = false;
      description = "Enable automatic security hardening (use with caution)";
    };
    
    reportPath = mkOption {
      type = types.str;
      default = "/var/lib/ai-analysis/security-reports";
      description = "Path to store security audit reports";
    };
    
    scheduleInterval = mkOption {
      type = types.str;
      default = "weekly";
      description = "How often to run security audits";
    };
  };

  config = mkIf cfg.enable {
    # Main security audit service
    systemd.services.ai-security-audit = {
      description = "AI Security Audit Service";
      after = [ "network.target" ];
      wants = [ "network.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "ai-security-audit" ''
          #!/bin/bash
          
          # Configuration
          AUDIT_LEVEL="${cfg.auditLevel}"
          AUTO_HARDENING="${if cfg.autoHardening then "true" else "false"}"
          REPORT_DIR="${cfg.reportPath}"
          HOSTNAME=$(hostname)
          TIMESTAMP=$(date +%Y%m%d_%H%M%S)
          REPORT_FILE="$REPORT_DIR/security_audit_$HOSTNAME_$TIMESTAMP.json"
          LOG_FILE="/var/log/ai-analysis/security-audit.log"
          
          # Ensure directories exist
          mkdir -p "$REPORT_DIR"
          mkdir -p "$(dirname "$LOG_FILE")"
          
          # Setup logging
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1
          
          echo "[$(date)] Starting security audit for $HOSTNAME"
          echo "[$(date)] Audit level: $AUDIT_LEVEL"
          echo "[$(date)] Auto-hardening: $AUTO_HARDENING"
          
          # Initialize findings arrays
          CRITICAL_FINDINGS=""
          HIGH_FINDINGS=""
          MEDIUM_FINDINGS=""
          LOW_FINDINGS=""
          RECOMMENDATIONS=""
          
          # Function to add finding
          add_finding() {
            local severity="$1"
            local category="$2"
            local description="$3"
            local recommendation="$4"
            
            local finding='{
              "category": "'$category'",
              "description": "'$description'",
              "recommendation": "'$recommendation'",
              "timestamp": "'$(date -Iseconds)'"
            }'
            
            case "$severity" in
              "critical")
                if [ -n "$CRITICAL_FINDINGS" ]; then
                  CRITICAL_FINDINGS="$CRITICAL_FINDINGS,$finding"
                else
                  CRITICAL_FINDINGS="$finding"
                fi
                ;;
              "high")
                if [ -n "$HIGH_FINDINGS" ]; then
                  HIGH_FINDINGS="$HIGH_FINDINGS,$finding"
                else
                  HIGH_FINDINGS="$finding"
                fi
                ;;
              "medium")
                if [ -n "$MEDIUM_FINDINGS" ]; then
                  MEDIUM_FINDINGS="$MEDIUM_FINDINGS,$finding"
                else
                  MEDIUM_FINDINGS="$finding"
                fi
                ;;
              "low")
                if [ -n "$LOW_FINDINGS" ]; then
                  LOW_FINDINGS="$LOW_FINDINGS,$finding"
                else
                  LOW_FINDINGS="$finding"
                fi
                ;;
            esac
            
            echo "[$(date)] [$severity] $category: $description"
          }
          
          # Function to execute hardening action
          execute_hardening() {
            local action="$1"
            local description="$2"
            local command="$3"
            
            if [ "$AUTO_HARDENING" = "true" ]; then
              echo "[$(date)] Executing hardening: $description"
              if eval "$command"; then
                echo "[$(date)] ✓ Hardening successful: $description"
                return 0
              else
                echo "[$(date)] ✗ Hardening failed: $description"
                return 1
              fi
            else
              echo "[$(date)] Hardening available: $description (auto-hardening disabled)"
              return 0
            fi
          }
          
          # === BASIC SECURITY AUDIT ===
          echo "[$(date)] === BASIC SECURITY AUDIT ==="
          
          # 1. SSH Configuration Security
          echo "[$(date)] Auditing SSH configuration..."
          
          if systemctl is-enabled ssh &>/dev/null || systemctl is-enabled sshd &>/dev/null; then
            # Check SSH root login
            if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null; then
              add_finding "high" "ssh_config" "Root login is enabled" "Disable root login: PermitRootLogin no"
            fi
            
            # Check SSH password authentication
            if grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config 2>/dev/null; then
              add_finding "medium" "ssh_config" "Password authentication enabled" "Use key-based authentication only"
            fi
            
            # Check SSH protocol version
            if grep -q "^Protocol 1" /etc/ssh/sshd_config 2>/dev/null; then
              add_finding "critical" "ssh_config" "SSH Protocol 1 enabled" "Use Protocol 2 only"
            fi
          fi
          
          # 2. File Permissions Audit
          echo "[$(date)] Auditing critical file permissions..."
          
          # Check /etc/passwd permissions
          PASSWD_PERMS=$(stat -c "%a" /etc/passwd 2>/dev/null || echo "000")
          if [ "$PASSWD_PERMS" != "644" ]; then
            add_finding "medium" "file_permissions" "/etc/passwd has incorrect permissions ($PASSWD_PERMS)" "Set permissions to 644"
          fi
          
          # Check /etc/shadow permissions
          SHADOW_PERMS=$(stat -c "%a" /etc/shadow 2>/dev/null || echo "000")
          if [ "$SHADOW_PERMS" != "640" ] && [ "$SHADOW_PERMS" != "600" ]; then
            add_finding "high" "file_permissions" "/etc/shadow has incorrect permissions ($SHADOW_PERMS)" "Set permissions to 640 or 600"
          fi
          
          # Check for world-writable files in critical directories
          WORLD_WRITABLE=$(find /etc /bin /sbin /usr/bin /usr/sbin -type f -perm -002 2>/dev/null | head -5)
          if [ -n "$WORLD_WRITABLE" ]; then
            add_finding "high" "file_permissions" "World-writable files found in system directories" "Review and fix file permissions"
          fi
          
          # 3. User Account Security
          echo "[$(date)] Auditing user accounts..."
          
          # Check for accounts with empty passwords
          EMPTY_PASSWORDS=$(awk -F: '($2 == "") {print $1}' /etc/shadow 2>/dev/null | head -5)
          if [ -n "$EMPTY_PASSWORDS" ]; then
            add_finding "critical" "user_accounts" "Accounts with empty passwords found" "Set passwords or disable accounts"
          fi
          
          # Check for duplicate UIDs
          DUPLICATE_UIDS=$(awk -F: '{print $3}' /etc/passwd | sort | uniq -d | head -5)
          if [ -n "$DUPLICATE_UIDS" ]; then
            add_finding "medium" "user_accounts" "Duplicate UIDs found" "Ensure unique UIDs for all users"
          fi
          
          # 4. Network Security
          echo "[$(date)] Auditing network security..."
          
          # Check for open ports
          OPEN_PORTS=$(ss -tuln | grep LISTEN | awk '{print $5}' | cut -d: -f2 | sort -u | tr '\n' ' ')
          echo "[$(date)] Open ports: $OPEN_PORTS"
          
          # Check for suspicious listening services
          if echo "$OPEN_PORTS" | grep -q "23\|513\|514\|2049"; then
            add_finding "medium" "network_security" "Potentially insecure services listening" "Review necessity of telnet, rsh, rlogin, or NFS services"
          fi
          
          # 5. System Updates and Patches
          echo "[$(date)] Checking system update status..."
          
          # Check last update time (NixOS specific)
          if [ -f /nix/var/nix/profiles/system ]; then
            LAST_UPDATE=$(stat -c %Y /nix/var/nix/profiles/system)
            CURRENT_TIME=$(date +%s)
            DAYS_SINCE_UPDATE=$(((CURRENT_TIME - LAST_UPDATE) / 86400))
            
            if [ "$DAYS_SINCE_UPDATE" -gt 30 ]; then
              add_finding "medium" "system_updates" "System not updated for $DAYS_SINCE_UPDATE days" "Run nixos-rebuild switch to update system"
            elif [ "$DAYS_SINCE_UPDATE" -gt 60 ]; then
              add_finding "high" "system_updates" "System not updated for $DAYS_SINCE_UPDATE days" "Immediate system update required"
            fi
          fi
          
          # === COMPREHENSIVE AUDIT (if enabled) ===
          if [ "$AUDIT_LEVEL" = "comprehensive" ] || [ "$AUDIT_LEVEL" = "advanced" ]; then
            echo "[$(date)] === COMPREHENSIVE SECURITY AUDIT ==="
            
            # 6. Process and Service Security
            echo "[$(date)] Auditing running processes and services..."
            
            # Check for processes running as root
            ROOT_PROCESSES=$(ps aux | awk '$1 == "root" {print $11}' | sort | uniq -c | sort -nr | head -10)
            
            # Check for failed services
            FAILED_SERVICES=$(systemctl list-units --state=failed --no-legend | cut -d' ' -f1 | head -5)
            if [ -n "$FAILED_SERVICES" ]; then
              add_finding "medium" "service_security" "Failed services detected: $FAILED_SERVICES" "Investigate and fix failed services"
            fi
            
            # 7. Kernel Security
            echo "[$(date)] Auditing kernel security settings..."
            
            # Check kernel parameters
            if [ "$(sysctl -n net.ipv4.ip_forward 2>/dev/null)" = "1" ]; then
              add_finding "medium" "kernel_security" "IP forwarding is enabled" "Disable if not needed: net.ipv4.ip_forward = 0"
            fi
            
            # Check if ASLR is enabled
            if [ "$(sysctl -n kernel.randomize_va_space 2>/dev/null)" != "2" ]; then
              add_finding "medium" "kernel_security" "ASLR not fully enabled" "Enable full ASLR: kernel.randomize_va_space = 2"
            fi
            
            # 8. Firewall Status
            echo "[$(date)] Auditing firewall configuration..."
            
            if ! systemctl is-active firewall &>/dev/null && ! iptables -L &>/dev/null 2>&1; then
              add_finding "high" "firewall" "No active firewall detected" "Enable and configure firewall"
            fi
            
            # 9. Log Security
            echo "[$(date)] Auditing log security..."
            
            # Check log file permissions
            LOG_PERMS=$(find /var/log -type f -perm -044 2>/dev/null | head -5)
            if [ -n "$LOG_PERMS" ]; then
              add_finding "medium" "log_security" "Log files readable by others" "Restrict log file permissions"
            fi
          fi
          
          # === ADVANCED AUDIT (if enabled) ===
          if [ "$AUDIT_LEVEL" = "advanced" ]; then
            echo "[$(date)] === ADVANCED SECURITY AUDIT ==="
            
            # 10. Cryptographic Security
            echo "[$(date)] Auditing cryptographic security..."
            
            # Check for weak SSH ciphers
            if ssh -Q cipher | grep -E "des|rc4|md5" &>/dev/null; then
              add_finding "medium" "crypto_security" "Weak SSH ciphers available" "Disable weak ciphers in SSH configuration"
            fi
            
            # 11. Container Security (if Docker is running)
            if systemctl is-active docker &>/dev/null; then
              echo "[$(date)] Auditing container security..."
              
              # Check Docker daemon configuration
              if ! docker info --format '{{.SecurityOptions}}' | grep -q "seccomp"; then
                add_finding "medium" "container_security" "Docker seccomp not enabled" "Enable seccomp in Docker daemon"
              fi
              
              # Check for privileged containers
              PRIVILEGED_CONTAINERS=$(docker ps --format "table {{.Names}}\t{{.Image}}" --filter "privileged=true" | tail -n +2)
              if [ -n "$PRIVILEGED_CONTAINERS" ]; then
                add_finding "high" "container_security" "Privileged containers running" "Review necessity of privileged containers"
              fi
            fi
            
            # 12. AI Analysis Integration Security
            echo "[$(date)] Auditing AI analysis security..."
            
            # Check AI API key storage
            if [ -d /run/agenix ]; then
              AI_KEY_PERMS=$(find /run/agenix -name "*api*" -exec stat -c "%a %n" {} \; 2>/dev/null)
              if echo "$AI_KEY_PERMS" | grep -v "600\|640"; then
                add_finding "high" "ai_security" "AI API keys have incorrect permissions" "Secure API key file permissions"
              fi
            fi
            
            # Check for exposed AI services
            if ss -tuln | grep -E ":8080|:11434" &>/dev/null; then
              add_finding "medium" "ai_security" "AI services exposed on all interfaces" "Restrict AI service access to localhost"
            fi
          fi
          
          # Calculate security score
          CRITICAL_COUNT=$(echo "$CRITICAL_FINDINGS" | grep -o '{"category"' | wc -l)
          HIGH_COUNT=$(echo "$HIGH_FINDINGS" | grep -o '{"category"' | wc -l)
          MEDIUM_COUNT=$(echo "$MEDIUM_FINDINGS" | grep -o '{"category"' | wc -l)
          LOW_COUNT=$(echo "$LOW_FINDINGS" | grep -o '{"category"' | wc -l)
          
          SECURITY_SCORE=$((100 - (CRITICAL_COUNT * 20) - (HIGH_COUNT * 10) - (MEDIUM_COUNT * 5) - (LOW_COUNT * 1)))
          [ "$SECURITY_SCORE" -lt 0 ] && SECURITY_SCORE=0
          
          # Determine security level
          SECURITY_LEVEL="excellent"
          if [ "$SECURITY_SCORE" -lt 90 ]; then
            SECURITY_LEVEL="good"
          fi
          if [ "$SECURITY_SCORE" -lt 75 ]; then
            SECURITY_LEVEL="moderate"
          fi
          if [ "$SECURITY_SCORE" -lt 60 ]; then
            SECURITY_LEVEL="poor"
          fi
          if [ "$SECURITY_SCORE" -lt 40 ]; then
            SECURITY_LEVEL="critical"
          fi
          
          # Generate comprehensive report
          cat > "$REPORT_FILE" << EOF
          {
            "audit_metadata": {
              "hostname": "$HOSTNAME",
              "timestamp": "$(date -Iseconds)",
              "audit_level": "$AUDIT_LEVEL",
              "auto_hardening_enabled": $AUTO_HARDENING,
              "auditor_version": "1.0"
            },
            "security_summary": {
              "security_score": $SECURITY_SCORE,
              "security_level": "$SECURITY_LEVEL",
              "findings_count": {
                "critical": $CRITICAL_COUNT,
                "high": $HIGH_COUNT,
                "medium": $MEDIUM_COUNT,
                "low": $LOW_COUNT,
                "total": $((CRITICAL_COUNT + HIGH_COUNT + MEDIUM_COUNT + LOW_COUNT))
              }
            },
            "security_findings": {
              "critical": [$CRITICAL_FINDINGS],
              "high": [$HIGH_FINDINGS],
              "medium": [$MEDIUM_FINDINGS],
              "low": [$LOW_FINDINGS]
            },
            "system_information": {
              "kernel_version": "$(uname -r)",
              "os_version": "$(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')",
              "last_boot": "$(uptime -s)",
              "current_users": $(who | wc -l),
              "running_services": $(systemctl list-units --type=service --state=running | wc -l)
            },
            "next_audit": "$(date -d "+$(echo ${cfg.scheduleInterval} | sed 's/ly//')" -Iseconds)"
          }
          EOF
          
          echo "[$(date)] Security audit completed"
          echo "[$(date)] Security score: $SECURITY_SCORE/100 ($SECURITY_LEVEL)"
          echo "[$(date)] Findings: $CRITICAL_COUNT critical, $HIGH_COUNT high, $MEDIUM_COUNT medium, $LOW_COUNT low"
          echo "[$(date)] Report saved to: $REPORT_FILE"
          
          # Send alerts for critical findings
          if [ "$CRITICAL_COUNT" -gt 0 ]; then
            logger -t ai-security-audit "CRITICAL: $CRITICAL_COUNT critical security findings detected on $HOSTNAME"
          fi
          
          echo "[$(date)] Security audit completed successfully"
        '';
      };
    };

    # Timer for regular security audits
    systemd.timers.ai-security-audit = {
      description = "AI Security Audit Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.scheduleInterval;
        Persistent = true;
        RandomizedDelaySec = "2h";
      };
    };

    # Quick security check service
    systemd.services.ai-security-check = {
      description = "AI Quick Security Check";
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "ai-security-check" ''
          #!/bin/bash
          
          echo "[$(date)] Running quick security check..."
          
          ISSUES=0
          
          # Quick checks for immediate security issues
          if ss -tuln | grep ":22" | grep -q "0.0.0.0"; then
            echo "WARNING: SSH exposed on all interfaces"
            ((ISSUES++))
          fi
          
          if [ -f /etc/shadow ] && [ "$(stat -c %a /etc/shadow)" != "640" ] && [ "$(stat -c %a /etc/shadow)" != "600" ]; then
            echo "WARNING: /etc/shadow has incorrect permissions"
            ((ISSUES++))
          fi
          
          if systemctl list-units --state=failed | grep -q "failed"; then
            echo "WARNING: Failed services detected"
            ((ISSUES++))
          fi
          
          if [ "$ISSUES" -gt 0 ]; then
            echo "RECOMMENDATION: Run full security audit with 'systemctl start ai-security-audit'"
          else
            echo "Quick security check passed"
          fi
        '';
      };
    };

    # Create directories for reports
    systemd.tmpfiles.rules = [
      "d ${cfg.reportPath} 0755 ai-analysis ai-analysis -"
      "d /var/log/ai-analysis 0755 ai-analysis ai-analysis -"
    ];

    # Install security audit tools
    environment.systemPackages = with pkgs; [
      nettools
      iproute2
      procps
      util-linux
    ];
  };
}