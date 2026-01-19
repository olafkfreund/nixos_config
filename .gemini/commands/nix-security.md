# NixOS Security Audit

Perform comprehensive security audit of your NixOS configuration.

## Quick Audit

Just run:
```
/nix-security
```

I'll automatically check all hosts and services for security issues.

## What I'll Check

### 1. Service Isolation ⚠️ CRITICAL

**DynamicUser Check:**
```nix
# ❌ INSECURE
systemd.services.myservice = {
  serviceConfig.User = "root";  # Running as root!
};

# ✅ SECURE
systemd.services.myservice = {
  serviceConfig = {
    DynamicUser = true;
    User = "myservice";
    Group = "myservice";
  };
};
```

**Score**: -10 points per root service

### 2. Systemd Hardening ⚠️ CRITICAL

**Required Options:**
```nix
serviceConfig = {
  # Isolation (REQUIRED)
  ProtectSystem = "strict";      # Read-only /usr, /boot, /etc
  ProtectHome = true;             # No access to /home
  PrivateTmp = true;              # Isolated /tmp

  # Security (REQUIRED)
  NoNewPrivileges = true;         # No privilege escalation
  RestrictSUIDSGID = true;        # No SUID/SGID

  # Additional Hardening (RECOMMENDED)
  ProtectKernelTunables = true;   # No kernel parameter access
  ProtectControlGroups = true;    # No cgroup modification
  PrivateDevices = true;          # No device access

  # Resource Limits (RECOMMENDED)
  MemoryMax = "1G";
  TasksMax = 1000;
};
```

**Score**: -5 points per missing critical option, -2 per missing recommended

### 3. Secret Management ⚠️ CRITICAL

**Evaluation-Time Secret Reads:**
```nix
# ❌ INSECURE - Secret exposed in Nix store!
password = builtins.readFile "/secrets/password";
apiKey = "sk-1234567890";

# ✅ SECURE - Runtime loading only
passwordFile = "/run/agenix/password";
apiKeyFile = config.age.secrets.api-key.path;
```

**Score**: -20 points per evaluation-time secret read

### 4. Firewall Configuration

**Port Security:**
```nix
# ❌ INSECURE
networking.firewall.enable = false;  # Firewall disabled!

# ⚠️ RISKY
networking.firewall.allowedTCPPorts = [ 22 80 443 8080 9090 3000 ];  # Too many ports

# ✅ SECURE
networking.firewall = {
  enable = true;
  allowedTCPPorts = [ 22 80 443 ];  # Minimal necessary ports
  interfaces."tailscale0".allowedTCPPorts = [ 9090 3000 ];  # Internal only
};
```

**Score**: -50 if firewall disabled, -3 per unnecessary open port

### 5. SSH Hardening

**SSH Security:**
```nix
# ❌ INSECURE
services.openssh = {
  enable = true;
  settings.PasswordAuthentication = true;  # Passwords enabled!
  settings.PermitRootLogin = "yes";        # Root login allowed!
};

# ✅ SECURE
services.openssh = {
  enable = true;
  settings = {
    PasswordAuthentication = false;        # Key-only
    PermitRootLogin = "no";               # No root
    X11Forwarding = false;                # Minimal features
    AllowUsers = [ "olafkfreund" ];      # Explicit users
  };
};
```

**Score**: -15 if password auth enabled, -20 if root login enabled

### 6. Agenix Secret Access

**Secret File Permissions:**
```nix
# ⚠️ REVIEW
age.secrets."api-key" = {
  file = ../secrets/api-key.age;
  mode = "0444";  # World readable! Should be 0400
};

# ✅ SECURE
age.secrets."api-key" = {
  file = ../secrets/api-key.age;
  mode = "0400";
  owner = config.services.myservice.user;
  group = config.services.myservice.group;
};
```

**Score**: -10 per world-readable secret

## Security Report Format

```
╔════════════════════════════════════════════════╗
║        NixOS SECURITY AUDIT REPORT             ║
╚════════════════════════════════════════════════╝

📊 Overall Score: 85/100 (Good)

⚠️  CRITICAL ISSUES (Must Fix Immediately):
  1. myservice running as root (hosts/p620/configuration.nix:245)
  2. API key in evaluation (modules/services/api.nix:67)

⚠️  HIGH PRIORITY (Fix Soon):
  3. Missing ProtectSystem on database service (modules/services/db.nix:123)
  4. Firewall has 8 open ports (hosts/p620/configuration.nix:89)

ℹ️  MEDIUM PRIORITY (Recommended):
  5. SSH X11Forwarding enabled (hosts/common/ssh.nix:34)
  6. Missing resource limits on web service (modules/services/web.nix:56)

✅ STRENGTHS:
  • All secrets use agenix encryption
  • Tailscale VPN properly configured
  • Most services use DynamicUser

📋 CHECKLIST:
  [❌] All services use DynamicUser (12/15 services)
  [✅] No evaluation-time secret reads (15/15)
  [⚠️] Firewall properly configured (3/4 hosts)
  [✅] SSH hardening enabled (4/4 hosts)
  [❌] Full systemd hardening (8/15 services)
```

## Automated Fixes

For each issue, I'll provide:
1. **Location**: Exact file and line number
2. **Issue**: What's wrong and why it's dangerous
3. **Fix**: Complete code replacement
4. **Explanation**: Security reasoning

**Example:**
```
Issue: Service running as root
Location: hosts/p620/configuration.nix:245
Severity: CRITICAL

Current code:
  systemd.services.myservice = {
    serviceConfig.User = "root";
  };

Suggested fix:
  systemd.services.myservice = {
    serviceConfig = {
      DynamicUser = true;
      User = "myservice";
      Group = "myservice";
      ProtectSystem = "strict";
      NoNewPrivileges = true;
    };
  };

Why: Running services as root violates least privilege principle.
If compromised, attacker has full system access. DynamicUser creates
isolated user with minimal permissions.
```

## Usage Modes

**Full Audit (All Hosts):**
```
/nix-security
```

**Specific Host:**
```
/nix-security
Audit p620 configuration
```

**Specific Service:**
```
/nix-security
Check myservice security
```

**Quick Check (Critical Only):**
```
/nix-security
Quick check for critical issues only
```

## Speed Optimization

- **Parallel Checking**: All hosts checked simultaneously
- **Pattern Matching**: Fast regex-based detection
- **Cached Results**: Re-check only changed files

**Typical Runtime**: 30-45 seconds for complete audit

## Integration

Automatically runs as part of:
- `/review` command (security section)
- `just validate` (security checks)
- Pre-commit hooks (optional)

## Scoring System

- **100**: Perfect security (all checks pass)
- **90-99**: Excellent (minor improvements possible)
- **80-89**: Good (some hardening needed)
- **70-79**: Fair (several issues to address)
- **< 70**: Poor (immediate action required)

Ready to audit your security? Just run `/nix-security`!
