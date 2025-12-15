# Security Audit Workflow

Complete security review and hardening cycle.

**Estimated Time:** 3-5 minutes total

## Workflow Steps

### 1. Run Security Audit (1 minute)

```bash
/nix-security
```

**What happens:**

- **Service Isolation Check**: Verifies all services use DynamicUser
- **Systemd Hardening Review**: Checks ProtectSystem, ProtectHome, NoNewPrivileges
- **Secret Management Audit**: Finds evaluation-time secret reads
- **Firewall Configuration**: Reviews open ports and rules
- **SSH Hardening**: Checks SSH configuration security
- **Generates Security Score**: 0-100 score with breakdown

**Report includes:**

- ✅ **Passed checks** (green)
- ⚠️ **Warnings** (yellow) - Should fix
- ❌ **Critical issues** (red) - Must fix
- 📊 **Security score** with improvement recommendations

### 2. Review Report (1 minute)

**Analyze findings:**

**Critical Issues (Must Fix):**

- Services running as root
- Secrets read during evaluation
- Firewall disabled or overly permissive
- SSH accepting password authentication
- Missing systemd hardening

**Warnings (Should Fix):**

- Incomplete systemd hardening
- Unnecessary open ports
- Weak SSH configuration
- Missing secret rotation

**Score Breakdown:**

- **90-100**: Excellent (production-ready)
- **80-89**: Good (minor improvements)
- **70-79**: Acceptable (some hardening needed)
- **60-69**: Weak (significant hardening required)
- **<60**: Critical (major security issues)

### 3. Apply Fixes (2 minutes)

**Auto-fix common issues:**

```bash
/nix-fix
```

**What gets fixed automatically:**

- Converts root services to DynamicUser
- Adds missing systemd hardening directives
- Fixes evaluation-time secret reads → runtime loading
- Removes unnecessary `mkIf true` patterns

**Manual fixes for critical issues:**

#### Service Running as Root

```nix
# ❌ BEFORE
systemd.services.myservice = {
  serviceConfig.ExecStart = "${pkgs.myapp}/bin/myapp";
};

# ✅ AFTER (auto-fixed by /nix-fix)
systemd.services.myservice = {
  serviceConfig = {
    ExecStart = "${pkgs.myapp}/bin/myapp";
    DynamicUser = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    NoNewPrivileges = true;
    PrivateTmp = true;
  };
};
```

#### Evaluation-Time Secret Read

```nix
# ❌ BEFORE
services.myservice.password = builtins.readFile "/secrets/pass";

# ✅ AFTER (auto-fixed by /nix-fix)
services.myservice.passwordFile = config.age.secrets.password.path;
```

#### Open Firewall Ports

```nix
# ❌ BEFORE
networking.firewall.enable = false;

# ✅ AFTER (manual fix)
networking.firewall = {
  enable = true;
  allowedTCPPorts = [ 22 80 443 ];  # Only necessary ports
  interfaces."tailscale0".allowedTCPPorts = [ 9090 3000 ];  # Internal only
};
```

#### SSH Hardening

```nix
# ❌ BEFORE
services.openssh.settings.PasswordAuthentication = true;

# ✅ AFTER (manual fix)
services.openssh = {
  enable = true;
  settings = {
    PasswordAuthentication = false;
    PermitRootLogin = "no";
    PubkeyAuthentication = true;
    X11Forwarding = false;
    AllowUsers = [ "your-user" ];
  };
};
```

### 4. Validate Fixes (1 minute)

```bash
/nix-security
# Run again to verify score improved
```

**Compare scores:**

- Before: 72/100 (Acceptable)
- After: 91/100 (Excellent)
- Improvement: +19 points

**Goal:** Achieve 85+ for production systems

### 5. Deploy Changes (Optional - if fixes made)

**If score improved and changes made:**

```bash
/nix-deploy
Deploy to p620
```

**Track security improvement:**

```bash
git add .
git commit -m "security: harden systemd services and fix secret handling

Improvements:
- Convert 5 services to DynamicUser
- Add comprehensive systemd hardening
- Fix evaluation-time secret reads
- Restrict firewall rules
- Harden SSH configuration

Security score: 72 → 91 (+19 points)

Relates to security audit"

git push
```

## Time Breakdown

| Step              | Time        | Command                    |
| ----------------- | ----------- | -------------------------- |
| Run audit         | 1 min       | `/nix-security`            |
| Review report     | 1 min       | Analyze findings           |
| Apply fixes       | 2 min       | `/nix-fix` + manual        |
| Validate          | 1 min       | `/nix-security`            |
| Deploy (optional) | 2 min       | `/nix-deploy`              |
| **TOTAL**         | **3-7 min** | **Complete audit + fixes** |

## Security Audit Schedule

### Daily (Automated)

- Automated checks in CI/CD
- Monitor for new vulnerabilities
- Check service status

### Weekly (Manual)

```bash
/nix-security
# Quick check, fix any new issues
```

### Monthly (Comprehensive)

```bash
# 1. Full security audit
/nix-security

# 2. Review all findings
# 3. Apply all fixes
/nix-fix

# 4. Manual hardening
# Review and improve security configuration

# 5. Re-audit
/nix-security

# 6. Deploy improvements
/nix-deploy
Deploy to all hosts

# 7. Document improvements
git commit -m "security: monthly hardening improvements"
```

### Quarterly (Deep Dive)

- Review secret rotation policies
- Audit user access and permissions
- Check for outdated packages with known CVEs
- Penetration testing
- Update security policies

## Security Checklist

### System Level

- [ ] Firewall enabled with minimal ports
- [ ] SSH hardened (no password auth, no root login)
- [ ] Automatic security updates enabled
- [ ] Kernel hardening parameters set
- [ ] SELinux/AppArmor configured (if applicable)

### Service Level

- [ ] All services use DynamicUser
- [ ] Systemd hardening applied (ProtectSystem, ProtectHome, etc.)
- [ ] Services run with minimal privileges
- [ ] No services running as root
- [ ] Service-specific firewall rules

### Secret Management

- [ ] All secrets managed with agenix
- [ ] No evaluation-time secret reads
- [ ] Runtime loading only (passwordFile patterns)
- [ ] Secrets rotated regularly
- [ ] Access control per host/user

### Network Security

- [ ] Tailscale VPN for remote access
- [ ] Internal services on Tailscale interface only
- [ ] Public services behind firewall
- [ ] SSL/TLS certificates valid
- [ ] DNS properly configured

### Application Security

- [ ] Dependencies up to date
- [ ] Known CVEs patched
- [ ] Security headers configured
- [ ] Input validation implemented
- [ ] Secure defaults enforced

## Common Security Issues & Fixes

### Issue: Services Running as Root

**Detection:**

```bash
/nix-security
# Reports: "Service 'myservice' running as root"
```

**Fix:**

```bash
/nix-fix
# Automatically converts to DynamicUser
```

**Manual verification:**

```bash
systemctl show myservice | grep ^User=
# Should show: User=myservice (not root)
```

### Issue: Secrets in Nix Store

**Detection:**

```bash
/nix-security
# Reports: "Secret read during evaluation in module X"
```

**Fix:**

```nix
# Change from:
password = builtins.readFile "/secrets/pass";

# To:
passwordFile = config.age.secrets.password.path;
```

### Issue: Open Firewall

**Detection:**

```bash
/nix-security
# Reports: "Firewall disabled" or "Too many open ports"
```

**Fix:**

```nix
networking.firewall = {
  enable = true;
  allowedTCPPorts = [ 22 ];  # Minimal ports
  interfaces."tailscale0".allowedTCPPorts = [ 9090 3000 ];  # Internal
};
```

### Issue: Weak SSH Configuration

**Detection:**

```bash
/nix-security
# Reports: "SSH allows password authentication"
```

**Fix:**

```nix
services.openssh.settings = {
  PasswordAuthentication = false;
  PermitRootLogin = "no";
  PubkeyAuthentication = true;
};
```

## Security Score Interpretation

### 90-100: Excellent ✅

- Production-ready
- Minimal risk
- Best practices followed
- Regular audits recommended

### 80-89: Good ⚠️

- Acceptable for production
- Minor improvements needed
- Some hardening opportunities
- Review monthly

### 70-79: Acceptable ⚠️

- Usable but needs improvement
- Security hardening required
- Review and fix warnings
- Audit weekly

### 60-69: Weak ❌

- Not recommended for production
- Significant security issues
- Immediate hardening required
- Daily audits until improved

### <60: Critical 🚨

- Do not deploy to production
- Major security vulnerabilities
- Immediate remediation required
- Block deployment until fixed

## Best Practices

### DO ✅

- Run `/nix-security` weekly
- Fix critical issues immediately
- Use `/nix-fix` for auto-fixes
- Track security score over time
- Deploy fixes promptly
- Document security improvements

### DON'T ❌

- Ignore security warnings
- Deploy with score <80
- Skip validation after fixes
- Use evaluation-time secrets
- Run services as root
- Disable firewall "temporarily"

## Related Workflows

- `/nix-workflow-feature` - Feature development (5-10 minutes)
- `/nix-workflow-bugfix` - Bug fixes (2-5 minutes)
- `/nix-help workflows` - All available workflows

---

**Pro Tip:** Set up automated weekly security audits in CI/CD. Run `/nix-security` as part of your deployment pipeline and block merges if score drops below 85.
