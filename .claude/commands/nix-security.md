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

## Automated Fixes

For each issue, I'll provide:

1. **Location**: Exact file and line number
2. **Issue**: What's wrong and why it's dangerous
3. **Fix**: Complete code replacement
4. **Explanation**: Security reasoning

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
