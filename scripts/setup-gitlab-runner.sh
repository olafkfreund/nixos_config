#!/usr/bin/env bash
#
# GitLab Runner Setup Script
# Deploys GitLab Runner configuration and registers runners with GitLab
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITLAB_TOKEN="${1:-glrt-Qx7Y4HT-y4b6RFN1TLLmBm86MQpwOjE5YWpwYwp0OjMKdTppMWh2Yxg.01.1j0uoules}"
GITLAB_URL="https://gitlab.com"

echo -e "${BLUE}=== GitLab Runner Setup for P620 ===${NC}\n"

# Step 0: Clean up existing runners
echo -e "${YELLOW}Step 0: Cleaning up existing runner registrations...${NC}"
if sudo gitlab-runner list 2>/dev/null | grep -q "Executor"; then
  echo -e "${YELLOW}Unregistering all existing runners...${NC}"
  sudo gitlab-runner unregister --all-runners || true
  echo -e "${GREEN}✅ Existing runners removed${NC}\n"
else
  echo -e "${BLUE}No existing runners found${NC}\n"
fi

# Remove old config to start fresh
sudo rm -f /etc/gitlab-runner/config.toml
echo -e "${GREEN}✅ Ready for fresh registration${NC}\n"

# Step 1: Deploy NixOS configuration (includes systemd service)
echo -e "${YELLOW}Step 1: Deploying NixOS configuration...${NC}"
if nh os switch --ask; then
  echo -e "${GREEN}✅ Configuration deployed successfully${NC}"
  echo -e "${GREEN}✅ GitLab Runner systemd service enabled${NC}\n"
else
  echo -e "${RED}❌ Configuration deployment failed${NC}"
  exit 1
fi

# Step 2: Register runners with GitLab
echo -e "${YELLOW}Step 2: Registering runners with GitLab...${NC}\n"

# Runner 1: Docker Runner (Alpine - lightweight and fast)
echo -e "${BLUE}Registering docker-alpine-runner...${NC}"
sudo gitlab-runner register \
  --non-interactive \
  --url "${GITLAB_URL}" \
  --token "${GITLAB_TOKEN}" \
  --name "docker-alpine-runner" \
  --executor "docker" \
  --docker-image "alpine:latest" \
  --docker-volumes "/cache"

echo -e "${GREEN}✅ docker-alpine-runner registered${NC}\n"

# Runner 2: Docker Runner (Ubuntu - common for most projects)
echo -e "${BLUE}Registering docker-ubuntu-runner...${NC}"
sudo gitlab-runner register \
  --non-interactive \
  --url "${GITLAB_URL}" \
  --token "${GITLAB_TOKEN}" \
  --name "docker-ubuntu-runner" \
  --executor "docker" \
  --docker-image "ubuntu:latest" \
  --docker-volumes "/cache"

echo -e "${GREEN}✅ docker-ubuntu-runner registered${NC}\n"

# Runner 3: Docker-in-Docker Runner (for building containers)
echo -e "${BLUE}Registering docker-dind-runner...${NC}"
sudo gitlab-runner register \
  --non-interactive \
  --url "${GITLAB_URL}" \
  --token "${GITLAB_TOKEN}" \
  --name "docker-dind-runner" \
  --executor "docker" \
  --docker-image "docker:latest" \
  --docker-privileged="true" \
  --docker-volumes "/cache" \
  --docker-volumes "/var/run/docker.sock:/var/run/docker.sock"

echo -e "${GREEN}✅ docker-dind-runner registered${NC}\n"

# Runner 4: Docker Runner (Node.js - for frontend/JS projects)
echo -e "${BLUE}Registering docker-node-runner...${NC}"
sudo gitlab-runner register \
  --non-interactive \
  --url "${GITLAB_URL}" \
  --token "${GITLAB_TOKEN}" \
  --name "docker-node-runner" \
  --executor "docker" \
  --docker-image "node:lts" \
  --docker-volumes "/cache"

echo -e "${GREEN}✅ docker-node-runner registered${NC}\n"

# Step 3: Fix permissions and start GitLab Runner service
echo -e "${YELLOW}Step 3: Setting up permissions and starting service...${NC}"
sudo chown -R gitlab-runner:gitlab-runner /etc/gitlab-runner
sudo chown -R gitlab-runner:gitlab-runner /var/lib/gitlab-runner
sudo chmod 700 /var/lib/gitlab-runner
sudo chmod 600 /etc/gitlab-runner/config.toml
echo -e "${GREEN}✅ Permissions set${NC}"

echo -e "${YELLOW}Starting GitLab Runner service...${NC}"
sudo systemctl start gitlab-runner
sleep 3

# Check if service started successfully
if sudo systemctl is-active gitlab-runner >/dev/null 2>&1; then
  echo -e "${GREEN}✅ GitLab Runner service started successfully${NC}\n"
else
  echo -e "${RED}❌ GitLab Runner service failed to start${NC}"
  echo -e "${YELLOW}Checking logs:${NC}"
  sudo journalctl -u gitlab-runner -n 20 --no-pager
  exit 1
fi

# Step 4: Verify runners
echo -e "${YELLOW}Step 4: Verifying registered runners...${NC}\n"
sudo gitlab-runner list

echo ""
echo -e "${GREEN}=== GitLab Runner Setup Complete! ===${NC}\n"

# Display summary
echo -e "${BLUE}Summary:${NC}"
echo -e "  • 4 runners registered successfully"
echo -e "  • docker-alpine-runner: Lightweight Alpine Linux base"
echo -e "  • docker-ubuntu-runner: Ubuntu for most common projects"
echo -e "  • docker-dind-runner: Docker-in-Docker for container builds"
echo -e "  • docker-node-runner: Node.js LTS for frontend/JS projects"
echo ""

echo -e "${BLUE}⚠️  Important - Configure runners in GitLab UI:${NC}"
echo -e "  1. Go to: ${YELLOW}https://gitlab.com/your-project/-/settings/ci_cd#runners${NC}"
echo -e "  2. Click 'Edit' on each runner to configure:"
echo -e "     • ${YELLOW}Tags${NC}: Add tags like 'docker', 'linux', 'alpine', 'ubuntu', 'dind'"
echo -e "     • ${YELLOW}Maximum job timeout${NC}: Set to 7200 seconds (2 hours)"
echo -e "     • ${YELLOW}Run untagged jobs${NC}: Enable or disable as needed"
echo -e "     • ${YELLOW}Protected${NC}: Configure access level"
echo ""

echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Configure runner tags and settings in GitLab UI (see above)"
echo -e "  2. Monitor runner service:"
echo -e "     ${YELLOW}sudo systemctl status gitlab-runner${NC}"
echo -e "  3. View runner logs:"
echo -e "     ${YELLOW}sudo journalctl -u gitlab-runner -f${NC}"
echo -e "  4. Create a test .gitlab-ci.yml file to test the runners"
echo ""

echo -e "${GREEN}✅ All done! Your GitLab Runners are ready to use.${NC}"
