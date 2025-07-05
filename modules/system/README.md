# System Configuration Modules

This directory contains low-level system configuration modules that manage core system functionality.

## Available Modules

### Performance and Optimization
- **performance.nix** - System performance tuning and optimization settings

## Module Overview

### Performance (`performance.nix`)
Provides comprehensive system performance optimizations including:
- CPU scheduler optimizations
- Memory management tuning
- I/O scheduler configuration
- Network stack optimizations
- Power management settings
- Kernel parameter tuning

## Usage Examples

### Basic Performance Optimization
```nix
{
  modules.system.performance = {
    enable = true;
    profile = "desktop";  # or "server", "laptop", "gaming"
  };
}
```

### Custom Performance Tuning
```nix
{
  modules.system.performance = {
    enable = true;
    cpu = {
      scheduler = "performance";
      governor = "performance";
    };
    memory = {
      swappiness = 10;
      enableZRAM = true;
    };
    io = {
      scheduler = "mq-deadline";
    };
  };
}
```

### Gaming-Optimized Configuration
```nix
{
  modules.system.performance = {
    enable = true;
    profile = "gaming";
    gaming = {
      enableGameMode = true;
      disableWatchdog = true;
      optimizeLatency = true;
    };
  };
}
```

## Performance Profiles

### Desktop Profile
- Balanced performance and power efficiency
- Optimized for interactive workloads
- Reasonable resource limits
- Moderate I/O scheduling

### Server Profile
- Maximum throughput optimization
- Aggressive caching and buffering
- Network stack tuning for high loads
- Minimal power management interference

### Laptop Profile
- Power efficiency focused
- Thermal throttling protection
- Battery life optimization
- Dynamic performance scaling

### Gaming Profile
- Low latency optimizations
- Real-time scheduling priorities
- Disabled power saving features
- Optimized graphics and audio paths

## Configuration Categories

### CPU Optimization
- Scheduler algorithm selection (CFS, deadline, RT)
- CPU governor configuration (performance, powersave, ondemand)
- Core isolation for specific workloads
- NUMA topology awareness

### Memory Management
- Swappiness tuning (0-100 scale)
- ZRAM compression for additional memory
- Transparent huge pages configuration
- OOM killer tuning

### Storage I/O
- I/O scheduler selection (mq-deadline, kyber, bfq)
- Read-ahead optimization
- Dirty page writeback tuning
- SSD-specific optimizations

### Network Tuning
- TCP congestion control algorithms
- Buffer size optimization
- Interrupt mitigation
- Network queue management

## Hardware-Specific Considerations

### SSD Storage
- Enable TRIM support
- Disable access time updates
- Optimize mount options
- Reduce write amplification

### Multi-Core Systems
- CPU affinity management
- IRQ balancing
- NUMA memory policies
- Cache optimization

### High-Memory Systems
- Large page support
- Memory compaction tuning
- Swap configuration
- Dirty ratio adjustments

## Monitoring and Validation

### Performance Metrics
```bash
# CPU performance
htop
sar -u 1 5

# Memory usage
free -h
vmstat 1 5

# I/O performance  
iostat -x 1 5
iotop

# Network performance
iftop
nethogs
```

### Benchmarking
```bash
# CPU benchmark
sysbench cpu run

# Memory benchmark
sysbench memory run

# I/O benchmark
fio --name=randwrite --rw=randwrite --bs=4k --size=1G

# Network benchmark
iperf3 -c server_ip
```

## Troubleshooting

### Common Issues

1. **High CPU usage after optimization**
   - Check if performance governor is stuck
   - Verify thermal throttling isn't occurring
   - Review IRQ distribution

2. **Memory pressure with ZRAM**
   - Adjust ZRAM compression ratio
   - Monitor swap usage patterns
   - Consider increasing physical memory

3. **I/O performance degradation**
   - Check filesystem fragmentation
   - Verify SSD TRIM is working
   - Monitor device temperature

### Debug Commands
```bash
# Check current CPU governor
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Monitor thermal state
cat /proc/acpi/thermal_zone/*/temperature

# Check I/O scheduler
cat /sys/block/*/queue/scheduler

# View kernel parameters
sysctl -a | grep -E "(vm|net|kernel)"
```

## Safety Considerations

- **Backup critical data** before applying performance optimizations
- **Test thoroughly** in non-production environments first
- **Monitor temperatures** to prevent thermal damage
- **Validate stability** under sustained load
- **Document changes** for future reference

Performance tuning can significantly impact system stability and should be applied incrementally with proper monitoring.