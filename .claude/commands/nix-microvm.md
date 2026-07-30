# NixOS MicroVM Management

Manage lightweight MicroVM development environments with minimal overhead.

**Replaces Justfile recipes**: `list-microvms`, `stop-all-microvms`, `clean-microvms`, `test-all-microvms`, `microvm-help`

## Quick Usage

**List all VMs**:

```
/nix-microvm
List VMs
```

**Start a VM**:

```
/nix-microvm
Start dev-vm
```

**Stop a VM**:

```
/nix-microvm
Stop dev-vm
```

**SSH into VM**:

```
/nix-microvm
SSH dev-vm
```

## Features

### Available MicroVMs

**dev-vm** (Development Environment):

- Purpose: Full development stack
- Resources: 8GB RAM, 4 CPU cores
- SSH: `ssh dev@localhost -p 2222` (password: dev)
- Web Ports: 8080 (HTTP), 3000 (dev server)
- Tools: Git, Node.js, Python, Go, Rust, Docker
- Storage: `/home/dev/projects` (persistent)

**test-vm** (Testing Environment):

- Purpose: Isolated testing sandbox
- Resources: 8GB RAM, 4 CPU cores
- SSH: `ssh test@localhost -p 2223` (password: test)
- Tools: Git, Python, testing utilities
- Storage: Clean slate on each restart

**playground-vm** (Experimental Sandbox):

- Purpose: Advanced tooling experiments
- Resources: 8GB RAM, 4 CPU cores
- SSH: `ssh root@localhost -p 2224` (password: playground)
- Web Ports: 8081 (HTTP)
- Tools: Kubernetes, Helm, Ansible, network analysis
- Storage: `/root/experiments` (persistent)

### MicroVM Operations

**List** (instant):

- ✅ Shows all configured VMs
- ✅ Running status
- ✅ Resource usage
- ✅ SSH connection info
- ✅ Port mappings

**Start** (~30 seconds):

- ✅ Starts specified VM
- ✅ Automatic network setup
- ✅ Port forwarding configuration
- ✅ Shared storage mounting
- ✅ SSH access enabled

**Stop** (~5 seconds):

- ✅ Graceful shutdown
- ✅ Data persistence
- ✅ Clean resource release
- ✅ Port unbinding

**Stop All** (~15 seconds):

- ✅ Stops all running VMs
- ✅ Sequential shutdown
- ✅ Waits for clean exit
- ✅ Verifies all stopped

**SSH** (instant):

- ✅ Direct SSH connection
- ✅ Automatic port selection
- ✅ Password authentication
- ✅ Or use SSH keys

**Restart** (~35 seconds):

- ✅ Stop + Start
- ✅ Fresh environment
- ✅ Persistent data retained
- ✅ Network reconfiguration

**Clean** (~10 seconds):

- ✅ Stops all VMs
- ✅ Removes VM data
- ✅ Cleans up resources
- ✅ WARNING: Destructive!

**Test** (~2 minutes):

- ✅ Validates VM configurations
- ✅ Tests all VMs build
- ✅ Checks resource allocation
- ✅ Verifies network setup

## MicroVM Workflow

### Development Workflow

**Step 1: Start Development VM**

```bash
/nix-microvm
Start dev-vm

# VM is ready!
```

**Step 2: SSH into VM**

```bash
/nix-microvm
SSH dev-vm

# Or manually:
ssh dev@localhost -p 2222
# Password: dev
```

**Step 3: Work on Projects**

```bash
# Inside VM
cd /home/dev/projects
git clone https://github.com/your/project.git
cd project

# Develop, test, build
npm install
npm run dev
# Access at http://localhost:3000
```

**Step 4: Access Shared Files**

```bash
# Inside VM
ls /mnt/shared
# Files shared with host
```

**Step 5: Stop When Done**

```bash
/nix-microvm
Stop dev-vm

# Or exit SSH and stop from host
exit
/nix-microvm
Stop dev-vm
```

### Testing Workflow

**Fresh Test Environment**:

```bash
# Start clean VM
/nix-microvm
Start test-vm

# Run tests
/nix-microvm
SSH test-vm

# Inside VM
./run-tests.sh

# Exit and stop
exit

# Next test gets fresh environment
/nix-microvm
Restart test-vm
```

### Playground Workflow

**Experiment with Tools**:

```bash
# Start playground
/nix-microvm
Start playground-vm

# SSH as root
/nix-microvm
SSH playground-vm

# Inside VM (as root)
cd /root/experiments
kubectl apply -f deployment.yaml
```

## Output Format

### Start VM Output

```
🚀 Starting MicroVM: dev-vm

📋 Configuration
   Type:       Development Environment
   RAM:        8 GB
   CPUs:       4 cores
   Storage:    /home/dev/projects (persistent)
   Network:    NAT with port forwarding

🔧 Starting VM...
   ✅ Allocating resources
   ✅ Configuring network
   ✅ Mounting shared storage
   ✅ Starting VM

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ dev-vm Started Successfully
Time: 28 seconds

Access:
  SSH:  ssh dev@localhost -p 2222
  Pass: dev
  Web:  http://localhost:8080
        http://localhost:3000

Shared Storage: /tmp/microvm-shared
Projects Dir:   /home/dev/projects

To connect: /nix-microvm SSH dev-vm
```

### Stop VM Output

```
⏸️  Stopping MicroVM: dev-vm

🛑 Shutting down gracefully...
   ✅ Syncing data
   ✅ Stopping services
   ✅ Releasing resources
   ✅ Unbinding ports

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ dev-vm Stopped
Time: 4 seconds

Data preserved in: /var/lib/microvms/dev-vm
To restart: /nix-microvm Start dev-vm
```

## Implementation Details

### List Command

```bash
# Check systemd services
systemctl list-units 'microvm@*.service'

# Get resource usage
systemctl status microvm@dev-vm.service
journalctl -u microvm@dev-vm.service -n 10
```

### Start Command

```bash
# Start via systemd
sudo systemctl start microvm@dev-vm.service

# Wait for startup
sleep 5

# Verify running
systemctl is-active microvm@dev-vm.service
```

### Stop Command

```bash
# Stop via systemd
sudo systemctl stop microvm@dev-vm.service

# Wait for clean shutdown
sleep 2

# Verify stopped
systemctl is-active microvm@dev-vm.service
```

### SSH Command

```bash
# Determine port from VM type
PORT=2222  # dev-vm

# Connect
ssh -p $PORT user@localhost
```

### Clean Command

```bash
# Stop all VMs
sudo systemctl stop 'microvm@*.service'

# Remove data
sudo rm -rf /var/lib/microvms/*

# Verify
ls -la /var/lib/microvms/
```

## Resource Management

### Per-VM Resources

**Each VM Gets**:

- 8GB RAM (configurable in flake.nix)
- 4 CPU cores (configurable)
- Dedicated network namespace
- Port forwarding to host
- Shared /nix/store (efficient)

**Total for 3 VMs**:

- 24GB RAM (if all running)
- 12 CPU cores allocated
- Minimal disk overhead (shared store)

### Host Requirements

**Minimum**:

- 32GB RAM (for running all 3 VMs + host)
- 8+ CPU cores
- 50GB free disk space

**Recommended**:

- 64GB RAM
- 12+ CPU cores
- 100GB+ free disk space

## Storage Configuration

### Shared Storage

**Host → VM Sharing**:

- `/tmp/microvm-shared` accessible in all VMs
- Files persist between VM restarts
- Shared across all VMs

### Persistent Storage

**dev-vm**:

- `/home/dev/projects` persists across restarts
- Projects saved automatically

**playground-vm**:

- `/root/experiments` persists
- Experiment data retained

**test-vm**:

- No persistent storage (clean slate)
- Fresh environment each restart

## Network Configuration

### Port Forwarding

**dev-vm**:

- 2222 → 22 (SSH)
- 8080 → 8080 (HTTP)
- 3000 → 3000 (dev server)

**test-vm**:

- 2223 → 22 (SSH)

**playground-vm**:

- 2224 → 22 (SSH)
- 8081 → 8080 (HTTP)

### Network Access

**VM → Host**:

- Full access to host network
- Can reach host services

**VM → Internet**:

- NAT networking
- Full internet access

**VM → VM**:

- Can communicate via host
- Use host IP from inside VMs

## Best Practices

### DO ✅

- Stop VMs when not in use (free resources)
- Use dev-vm for development work
- Use test-vm for clean testing
- Use playground-vm for experiments
- Check VM status regularly (`/nix-microvm List`)
- Back up important project files

### DON'T ❌

- Run all VMs simultaneously (high resource usage)
- Store critical data only in VMs (back up!)
- Use clean command without backups (destructive!)
- Forget to stop VMs (waste resources)
- Mix development and testing in same VM

## Troubleshooting

### VM Won't Start

```bash
# Check if already running
/nix-microvm
List VMs

# Check system resources
free -h
top

# Check logs
journalctl -u microvm@dev-vm.service -n 50

# Try restarting
/nix-microvm
Restart dev-vm
```

### Can't Connect via SSH

```bash
# Verify VM is running
/nix-microvm
List VMs

# Check port forwarding
ss -tlnp | grep 2222

# Try different port/VM
/nix-microvm
SSH test-vm
```

### Out of Resources

```bash
# Stop unused VMs
/nix-microvm
Stop all VMs

# Check resource usage
htop

# Reduce VM count or adjust resources in flake.nix
```

### Data Lost

```bash
# Check if persistent storage configured
ls -la /var/lib/microvms/dev-vm/

# Use dev-vm or playground-vm for persistent work
```

## Integration with Other Commands

### Before Development

```bash
# Start environment
/nix-microvm
Start dev-vm

# Verify it's running
/nix-microvm
List VMs

# Connect
/nix-microvm
SSH dev-vm
```

### After Testing

```bash
# Clean test environment
/nix-microvm
Restart test-vm

# Fresh start for next test
```

## Related Commands

- `/nix-test` - Test host configurations
- `/nix-validate` - Validate configurations
- `/nix-deploy` - Deploy to hosts
- `/nix-info` - Check system resources

---

**Pro Tip**: Create VM startup aliases in your shell:

```bash
alias dev='claude /nix-microvm && echo "Start dev-vm" && sleep 30 && ssh dev@localhost -p 2222'
alias test='claude /nix-microvm && echo "Start test-vm" && sleep 30 && ssh test@localhost -p 2223'
```

Instant development environments! 🚀
