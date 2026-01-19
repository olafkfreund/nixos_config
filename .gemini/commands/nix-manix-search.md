# Search NixOS Options and Packages with Manix

Search NixOS options, packages, and documentation using manix - the fast CLI documentation searcher.

## Quick Start

Just tell me what you're looking for:

1. Service name (e.g., "nginx", "postgresql", "prometheus")
2. Package name (e.g., "firefox", "docker", "kubernetes")
3. NixOS option path (e.g., "services.nginx.enable", "programs.git")

I'll search comprehensively and show you all available options.

## What I'll Do

### 1. Search with Manix

**For Services:**

```bash
# Find all nginx options
manix services.nginx

# Find specific option
manix services.nginx.enable

# Strict search (exact match)
manix --strict services.nginx.virtualHosts

# Update cache first (for latest options)
manix --update-cache services.nginx
```

**For Packages:**

```bash
# Search for package
manix pkgs.firefox

# Search lib functions
manix lib.mkIf

# Search for any package-related info
manix docker
```

**For Home Manager:**

```bash
# Search Home Manager options
manix programs.git

# Find home-manager specific config
manix home-manager
```

### 2. Interactive Search with fzf

I'll provide an interactive fuzzy-search interface:

```bash
# Interactive search with live preview
manix "" | grep '^# ' | sed 's/^# \(.*\) (.*/\1/;s/ (.*//' | \
  fzf --preview="manix '{}'" | xargs manix

# Search and select from results
manix services.nginx | fzf --preview="echo {}"
```

### 3. Combine with Online Documentation

I'll also search online resources:

**NixOS Search (search.nixos.org):**

- Options: <https://search.nixos.org/options>
- Packages: <https://search.nixos.org/packages>

**Nixpkgs GitHub:**

- Module source: <https://github.com/NixOS/nixpkgs/tree/master/nixos/modules>

### 4. Comprehensive Search Strategy

For any service/package, I'll:

1. **Manix local search** - Fast, offline documentation
2. **Online NixOS Search** - Complete option tree and examples
3. **GitHub source code** - Implementation details and defaults
4. **NixOS Wiki** - Community tutorials and patterns

## What Manix Searches

Manix searches across:

- ✅ **Nixpkgs Documentation** - Official package docs
- ✅ **Nixpkgs Comments** - Inline documentation
- ✅ **Nixpkgs Tree** - All pkgs._and pkgs.lib._ functions
- ✅ **NixOS Options** - All services._, programs._, etc.
- ✅ **Home-Manager Options** - User environment configuration

## Practical Examples

### Example 1: Configure Nginx

**Search for all nginx options:**

```bash
manix services.nginx
```

**Find specific features:**

```bash
manix services.nginx.virtualHosts
manix services.nginx.ssl
manix services.nginx.acme
```

**Interactive exploration:**

```bash
manix services.nginx | fzf --preview="manix '{}'"
```

### Example 2: Find Package Information

**Search for docker package:**

```bash
manix pkgs.docker

# Find related packages
manix docker-compose
manix containerd
```

### Example 3: Library Functions

**Find mkIf usage:**

```bash
manix lib.mkIf

# Find all mk* functions
manix lib.mk
```

### Example 4: Home Manager Configuration

**Search git configuration:**

```bash
manix programs.git
manix programs.git.enable
manix programs.git.extraConfig
```

## Advanced Usage

### Search with Context

```bash
# Show all results for a service
manix services.postgresql 2>&1 | less

# Search and save to file
manix services.nginx > nginx-options.txt

# Count available options
manix services.nginx 2>&1 | grep '^# ' | wc -l
```

### Combine Multiple Searches

```bash
# Search multiple related options
for opt in enable port settings; do
  echo "=== services.nginx.$opt ==="
  manix services.nginx.$opt
done
```

### Find Option Types

Manix shows option types (boolean, string, attribute set, etc.):

```text
# services.nginx.enable
Whether to enable Nginx Web Server.
type: boolean

# services.nginx.package
Which nginx package to use.
type: package
```

## Integration with Development Workflow

### When Creating Modules

**Before creating a new service module:**

1. **Search existing options:**

   ```bash
   manix services.{service-name}
   ```

2. **Check if module exists:**
   - If options found → Use existing module
   - If not found → Create new module with `/nix-module`

3. **Study similar services:**

   ```bash
   # Find similar service for patterns
   manix services.nginx  # Example for web servers
   manix services.postgresql  # Example for databases
   ```

### When Configuring Services

**Search order:**

1. **Local manix search** (fastest):

   ```bash
   manix services.{service}.{option}
   ```

2. **Online NixOS search** (most complete):
   - Visit: <https://search.nixos.org/options?query=services.{service}>

3. **Source code** (implementation details):
   - Check: nixpkgs/nixos/modules/services/\*/

### When Troubleshooting

**Find available options:**

```bash
# What options does this service support?
manix services.{service} 2>&1 | grep '^# ' | sed 's/^# //'

# Find specific configuration path
manix services.{service}.{config-path}
```

## Best Practices

### ✅ DO

1. **Always search before creating** - Check if module/option exists
2. **Use strict search** - Add `--strict` for exact matches
3. **Update cache regularly** - Use `--update-cache` for latest docs
4. **Combine with fzf** - Interactive search is faster
5. **Check option types** - Understand boolean vs string vs attrset
6. **Read descriptions** - Understand what options do
7. **Search online too** - Manix + search.nixos.org = complete picture

### ❌ DON'T

1. **Don't guess option names** - Always search first
2. **Don't skip documentation** - Read option descriptions
3. **Don't assume types** - Check if option is boolean, string, etc.
4. **Don't use outdated cache** - Update cache for new options
5. **Don't limit to manix** - Also check online documentation
6. **Don't create duplicate modules** - Search thoroughly first

## Output Format

Manix provides structured output:

```text
NixOS Options
────────────────────
# services.nginx.enable
Whether to enable Nginx Web Server.
type: boolean

NixOS Options
────────────────────
# services.nginx.package
Which nginx package to use.
type: package
default: pkgs.nginx
```

**Key sections:**

- **Header:** Source type (NixOS Options, Nixpkgs, etc.)
- **Title:** Full option path
- **Description:** What the option does
- **Type:** Data type expected
- **Default:** Default value (if any)
- **Example:** Usage example (if any)

## Search Tips

### Wildcards and Patterns

```bash
# Find all services
manix services.

# Find all nginx-related
manix nginx

# Find lib functions
manix lib.

# Find all enable options
manix enable
```

### Filtering Results

```bash
# Find only NixOS options (not packages)
manix services.nginx 2>&1 | grep -A5 "NixOS Options"

# Find options with specific type
manix services.nginx 2>&1 | grep -B2 "type: boolean"

# Extract option paths only
manix services.nginx 2>&1 | grep '^# ' | sed 's/^# //' | sed 's/ (.*//'
```

## When to Use This Command

**Use `/nix-manix-search` when:**

1. ✅ Adding new services to NixOS configuration
2. ✅ Configuring existing services (find available options)
3. ✅ Looking for package information
4. ✅ Searching for lib functions and helpers
5. ✅ Configuring Home Manager programs
6. ✅ Verifying option names and types before use
7. ✅ Exploring what's available in NixOS
8. ✅ Learning about NixOS options and their defaults

**Combine with:**

- `/nix-module` - After confirming no existing module
- `/nix-review` - To verify option usage is correct
- `/nix-fix` - To fix incorrect option usage
- Online search - For complete documentation and examples

## Speed Optimization

This command completes in **under 30 seconds**:

- 5s: Manix local search (very fast)
- 10s: Parse and format results
- 10s: Online search (if needed)
- 5s: Provide comprehensive summary

## Example Workflow

### Scenario: Adding PostgreSQL to a host

```bash
# 1. Search for PostgreSQL options
/nix-manix-search
Search for: services.postgresql

# 2. Explore interactively
manix services.postgresql | fzf --preview="manix '{}'"

# 3. Find specific options needed
manix services.postgresql.enable
manix services.postgresql.package
manix services.postgresql.settings
manix services.postgresql.authentication

# 4. Check online for examples
# Visit: https://search.nixos.org/options?query=services.postgresql

# 5. Configure in host
# Add to hosts/*/configuration.nix:
services.postgresql = {
  enable = true;
  package = pkgs.postgresql_16;
  # ... other options found via search
};
```

## Command Reference

**Basic Searches:**

```bash
manix {search-term}              # Basic search
manix --strict {exact-term}      # Exact match only
manix --update-cache {term}      # Update cache first
manix "" | grep '^# '            # List all options
```

**With fzf (Interactive):**

```bash
manix "" | grep '^# ' | sed 's/^# \(.*\) (.*/\1/;s/ (.*//' | \
  fzf --preview="manix '{}'" | xargs manix
```

**Filtering:**

```bash
manix {term} 2>&1 | grep -A5 "NixOS Options"
manix {term} 2>&1 | grep "type:"
```

## Success Indicators

- ✅ Found exact option path needed
- ✅ Understood option type and default value
- ✅ Read option description and behavior
- ✅ Verified no existing similar module/option
- ✅ Checked online documentation for examples
- ✅ Ready to configure or create module correctly

## Additional Resources

**Official Tools:**

- Manix: Fast local documentation search
- NixOS Search: <https://search.nixos.org>
- Nixpkgs GitHub: <https://github.com/NixOS/nixpkgs>

**Integration:**

- With fzf for interactive search
- With grep/sed for filtering
- With editors (rnix-lsp) for hover documentation

Ready to search? Tell me what service, package, or option you're looking for!
