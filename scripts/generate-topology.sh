#!/usr/bin/env bash
# scripts/generate-topology.sh
# Generates a JSON topology of the NixOS configuration for Gemini agents

set -euo pipefail
source scripts/gemini-adapter.sh

TOPOLOGY_FILE="topology.json"

echo "🔍 Scanning system topology..."

# Safe JSON array generation
safe_json_array() {
  local input="$1"
  if [ -z "$input" ]; then
    echo "[]"
  else
    echo "$input" | jq -R . | jq -s .
  fi
}

# Get hosts
RAW_HOSTS=$(find hosts -maxdepth 1 -type d 2>/dev/null | grep -v "hosts$" | grep -v "templates" | xargs -n 1 basename 2>/dev/null | sort || echo "")
HOSTS=$(safe_json_array "$RAW_HOSTS")
echo "DEBUG: HOSTS=$HOSTS"

# Get users
RAW_USERS=$(find Users -maxdepth 1 -type d 2>/dev/null | grep -v "Users$" | xargs -n 1 basename 2>/dev/null | sort || echo "")
USERS=$(safe_json_array "$RAW_USERS")
echo "DEBUG: USERS=$USERS"

# Get modules structure
RAW_MODULES=$(find modules -name "*.nix" 2>/dev/null | grep -v "default.nix" | sort || echo "")
MODULES=$(safe_json_array "$RAW_MODULES")
# Truncate module output for logs as it might be huge
echo "DEBUG: MODULES=$(echo "$MODULES" | head -c 100)..."

# Create JSON structure
# We'll use a temporary file to construct the JSON to avoid quoting hell
cat <<EOF >/tmp/topology_input.json
{
    "timestamp": "$(date -Iseconds)",
    "structure": {
        "p620": { "role": "workstation", "type": "amd" },
        "p510": { "role": "server", "type": "intel" },
        "razer": { "role": "laptop", "type": "intel-nvidia" },
        "samsung": { "role": "laptop", "type": "intel" },
        "dex5550": { "role": "sff", "type": "intel" }
    }
}
EOF

# Merge the arrays into the JSON
jq --argjson hosts "$HOSTS" \
  --argjson users "$USERS" \
  --argjson modules "$MODULES" \
  '. + {hosts: $hosts, users: $users, modules: $modules}' \
  /tmp/topology_input.json >".gemini/state/$TOPOLOGY_FILE"

echo "✅ Topology generated at .gemini/state/$TOPOLOGY_FILE"
