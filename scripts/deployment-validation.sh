#!/bin/bash

# AI Infrastructure Deployment Validation Script
# This script validates the complete AI infrastructure deployment across all hosts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Hosts to validate
HOSTS=("p620" "dex5550" "p510" "razer")
MONITORING_SERVER="dex5550"

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_success() {
    print_status "$GREEN" "✓ $1"
}

print_error() {
    print_status "$RED" "✗ $1"
}

print_warning() {
    print_status "$YELLOW" "⚠ $1"
}

print_info() {
    print_status "$BLUE" "ℹ $1"
}

# Function to check if a host is reachable
check_host_connectivity() {
    local host=$1
    if ping -c 1 "$host" &>/dev/null; then
        print_success "Host $host is reachable"
        return 0
    else
        print_error "Host $host is unreachable"
        return 1
    fi
}

# Function to check SSH connectivity
check_ssh_connectivity() {
    local host=$1
    if ssh -o ConnectTimeout=10 -o BatchMode=yes "$host" "echo 'SSH OK'" &>/dev/null; then
        print_success "SSH to $host is working"
        return 0
    else
        print_error "SSH to $host failed"
        return 1
    fi
}

# Function to check system services
check_system_services() {
    local host=$1
    print_info "Checking system services on $host..."
    
    # Check basic system services
    local services=("systemd-resolved" "NetworkManager" "sshd")
    
    for service in "${services[@]}"; do
        if ssh "$host" "systemctl is-active $service" &>/dev/null; then
            print_success "$host: $service is active"
        else
            print_warning "$host: $service is not active"
        fi
    done
}

# Function to check AI services
check_ai_services() {
    local host=$1
    print_info "Checking AI services on $host..."
    
    # Check AI-specific services based on host
    case $host in
        "p620")
            local ai_services=("ollama" "ai-alert-manager" "ai-production-dashboard")
            ;;
        "dex5550")
            local ai_services=("prometheus" "grafana")
            ;;
        "p510"|"razer")
            local ai_services=("ai-memory-optimization")
            ;;
    esac
    
    for service in "${ai_services[@]}"; do
        if ssh "$host" "systemctl is-active $service 2>/dev/null" &>/dev/null; then
            print_success "$host: $service is active"
        else
            print_warning "$host: $service is not active (may be timer-based)"
        fi
    done
}

# Function to check monitoring integration
check_monitoring_integration() {
    print_info "Checking monitoring integration..."
    
    # Check Prometheus targets
    local prometheus_url="http://${MONITORING_SERVER}.home.freundcloud.com:9090"
    if curl -s -f "$prometheus_url/api/v1/targets" &>/dev/null; then
        print_success "Prometheus server is accessible"
        
        # Check specific targets
        local targets=$(curl -s "$prometheus_url/api/v1/targets" | jq -r '.data.activeTargets[] | select(.health=="up") | .labels.instance')
        
        for host in "${HOSTS[@]}"; do
            if echo "$targets" | grep -q "$host"; then
                print_success "Monitoring target $host is UP"
            else
                print_warning "Monitoring target $host may be DOWN"
            fi
        done
    else
        print_error "Prometheus server is not accessible"
    fi
    
    # Check Grafana
    local grafana_url="http://${MONITORING_SERVER}.home.freundcloud.com:3001"
    if curl -s -f "$grafana_url/api/health" &>/dev/null; then
        print_success "Grafana server is accessible"
    else
        print_error "Grafana server is not accessible"
    fi
}

# Function to check AI provider functionality
check_ai_providers() {
    print_info "Checking AI provider functionality on P620..."
    
    # Check API key availability
    local api_keys=("api-anthropic" "api-openai" "api-gemini")
    for key in "${api_keys[@]}"; do
        if ssh p620 "test -f /run/agenix/$key"; then
            print_success "P620: $key is available"
        else
            print_error "P620: $key is missing"
        fi
    done
    
    # Check AI provider status
    if ssh p620 "ai-cli --status" &>/dev/null; then
        print_success "P620: AI provider system is functional"
    else
        print_warning "P620: AI provider system may have issues"
    fi
    
    # Test Ollama directly
    if ssh p620 "curl -s http://localhost:11434/api/tags" &>/dev/null; then
        print_success "P620: Ollama API is responding"
        
        # Get model count
        local model_count=$(ssh p620 "ollama list | wc -l")
        print_info "P620: Ollama has $((model_count-1)) models available"
    else
        print_error "P620: Ollama API is not responding"
    fi
}

# Function to check alerting system
check_alerting_system() {
    print_info "Checking alerting system on P620..."
    
    # Check alert manager service
    if ssh p620 "systemctl is-active ai-alert-manager" &>/dev/null; then
        print_success "P620: Alert manager is active"
    else
        print_error "P620: Alert manager is not active"
    fi
    
    # Check alert system status
    if ssh p620 "ai-alert-status" &>/dev/null; then
        print_success "P620: Alert system commands are functional"
    else
        print_warning "P620: Alert system commands may have issues"
    fi
    
    # Check alert thresholds
    local disk_usage=$(ssh p620 "df / | tail -1 | awk '{print \$5}' | sed 's/%//'")
    local memory_usage=$(ssh p620 "free | grep Mem | awk '{printf \"%.0f\", \$3/\$2 * 100.0}'")
    
    print_info "P620: Current disk usage: ${disk_usage}%"
    print_info "P620: Current memory usage: ${memory_usage}%"
    
    if [ "$disk_usage" -gt 80 ]; then
        print_warning "P620: Disk usage above 80% threshold"
    fi
    
    if [ "$memory_usage" -gt 85 ]; then
        print_warning "P620: Memory usage above 85% threshold"
    fi
}

# Function to check security configurations
check_security_config() {
    print_info "Checking security configurations..."
    
    for host in "${HOSTS[@]}"; do
        # Check SSH configuration
        if ssh "$host" "sudo sshd -t" &>/dev/null; then
            print_success "$host: SSH configuration is valid"
        else
            print_error "$host: SSH configuration has issues"
        fi
        
        # Check fail2ban (if installed)
        if ssh "$host" "systemctl is-active fail2ban" &>/dev/null; then
            print_success "$host: fail2ban is active"
        else
            print_warning "$host: fail2ban is not active"
        fi
    done
}

# Function to check network connectivity between hosts
check_network_connectivity() {
    print_info "Checking network connectivity between hosts..."
    
    for host1 in "${HOSTS[@]}"; do
        for host2 in "${HOSTS[@]}"; do
            if [ "$host1" != "$host2" ]; then
                if ssh "$host1" "ping -c 1 $host2" &>/dev/null; then
                    print_success "$host1 -> $host2: Network connectivity OK"
                else
                    print_error "$host1 -> $host2: Network connectivity failed"
                fi
            fi
        done
    done
}

# Function to check system resources
check_system_resources() {
    print_info "Checking system resources..."
    
    for host in "${HOSTS[@]}"; do
        local disk_usage=$(ssh "$host" "df / | tail -1 | awk '{print \$5}'")
        local memory_usage=$(ssh "$host" "free | grep Mem | awk '{printf \"%.1f%%\", \$3/\$2 * 100.0}'")
        local load_avg=$(ssh "$host" "uptime | awk -F'load average:' '{print \$2}' | awk '{print \$1}' | sed 's/,//'")
        
        print_info "$host: Disk: $disk_usage, Memory: $memory_usage, Load: $load_avg"
        
        # Check for concerning resource usage
        local disk_num=$(echo "$disk_usage" | sed 's/%//')
        if [ "$disk_num" -gt 90 ]; then
            print_warning "$host: High disk usage ($disk_usage)"
        fi
    done
}

# Function to generate summary report
generate_summary() {
    print_header "DEPLOYMENT VALIDATION SUMMARY"
    
    echo "Validation completed at: $(date)"
    echo "Hosts validated: ${HOSTS[*]}"
    echo "Monitoring server: $MONITORING_SERVER"
    
    print_info "Key Infrastructure Components:"
    print_info "  • AI Providers: Anthropic, OpenAI, Gemini, Ollama"
    print_info "  • Monitoring: Prometheus, Grafana, Node Exporters"
    print_info "  • Alerting: Email notifications, system monitoring"
    print_info "  • Security: SSH hardening, fail2ban protection"
    print_info "  • Storage: Automated analysis and optimization"
    
    print_info "Access Points:"
    print_info "  • Grafana: http://dex5550.home.freundcloud.com:3001"
    print_info "  • Prometheus: http://dex5550.home.freundcloud.com:9090"
    print_info "  • Alertmanager: http://dex5550.home.freundcloud.com:9093"
    
    print_success "AI Infrastructure deployment validation complete!"
}

# Main execution
main() {
    print_header "AI INFRASTRUCTURE DEPLOYMENT VALIDATION"
    print_info "Starting comprehensive validation of AI infrastructure..."
    print_info "Date: $(date)"
    
    # Basic connectivity checks
    print_header "CONNECTIVITY CHECKS"
    for host in "${HOSTS[@]}"; do
        check_host_connectivity "$host"
        check_ssh_connectivity "$host"
    done
    
    # System service checks
    print_header "SYSTEM SERVICE CHECKS"
    for host in "${HOSTS[@]}"; do
        check_system_services "$host"
    done
    
    # AI service checks
    print_header "AI SERVICE CHECKS"
    for host in "${HOSTS[@]}"; do
        check_ai_services "$host"
    done
    
    # Monitoring integration
    print_header "MONITORING INTEGRATION"
    check_monitoring_integration
    
    # AI provider functionality
    print_header "AI PROVIDER TESTING"
    check_ai_providers
    
    # Alerting system
    print_header "ALERTING SYSTEM"
    check_alerting_system
    
    # Security configurations
    print_header "SECURITY VALIDATION"
    check_security_config
    
    # Network connectivity
    print_header "NETWORK CONNECTIVITY"
    check_network_connectivity
    
    # System resources
    print_header "SYSTEM RESOURCES"
    check_system_resources
    
    # Generate summary
    generate_summary
}

# Run main function
main "$@"