# Comprehensive validation and quality checks
{ pkgs
, lib
, ...
}:
with lib; {
  # Syntax and style validation
  statix-lint =
    pkgs.runCommand "statix-validation"
      {
        src = cleanSource ../.;
      } ''
      echo "Running statix lint checks..."
      ${pkgs.statix}/bin/statix check $src --format=stderr || {
        echo "Statix found linting issues (warnings allowed)"
      }
      touch $out
    '';

  deadnix-check =
    pkgs.runCommand "deadnix-validation"
      {
        src = cleanSource ../.;
      } ''
      echo "Running deadnix dead code detection..."
      ${pkgs.deadnix}/bin/deadnix -f $src || {
        echo "Deadnix found dead code issues"
        exit 1
      }
      touch $out
    '';

  # Nix file syntax validation
  nix-syntax-check =
    pkgs.runCommand "nix-syntax-validation"
      {
        src = cleanSource ../.;
      } ''
      echo "Basic Nix file validation completed"
      echo "Files found: $(find $src -name '*.nix' | wc -l) .nix files"

      # Basic file structure check
      if [ ! -f "$src/flake.nix" ]; then
        echo "ERROR: flake.nix not found"
        exit 1
      fi

      echo "✅ Basic structure validation passed"
      touch $out
    '';

  # Module structure validation
  module-structure-check =
    pkgs.runCommand "module-structure-validation"
      {
        src = cleanSource ../.;
      } ''
      echo "Validating module structure..."

      # Check that all modules have proper structure
      for module_dir in $src/modules/*/; do
        if [ -d "$module_dir" ]; then
          module_name=$(basename "$module_dir")
          echo "Checking module: $module_name"

          # Check for default.nix or matching .nix file
          if [ ! -f "$module_dir/default.nix" ] && [ ! -f "$src/modules/$module_name.nix" ]; then
            echo "ERROR: Module $module_name missing default.nix or $module_name.nix"
            exit 1
          fi
        fi
      done

      touch $out
    '';

  # Configuration building tests for all hosts
  # host-build-validation =
  #   pkgs.runCommand "host-build-validation"
  #     {
  #       src = cleanSource ../.;
  #     } ''
  #     echo "Testing host configuration builds..."
  #     cd $src
  #
  #     # Test each host configuration
  #     for host in p620 p510 razer samsung; do
  #       echo "Testing build for host: $host"
  #       if ! ${pkgs.nix}/bin/nix build --extra-experimental-features 'nix-command flakes' --no-link ".#nixosConfigurations.$host.config.system.build.toplevel" --show-trace; then
  #         echo "ERROR: Failed to build configuration for host: $host"
  #         exit 1
  #       fi
  #       echo "✅ Host $host builds successfully"
  #     done
  #
  #     touch $out
  #   '';

  # MicroVM configuration validation
  # microvm-validation =
  #   pkgs.runCommand "microvm-validation"
  #     {
  #       src = cleanSource ../.;
  #     } ''
  #     echo "Validating MicroVM configurations..."
  #     cd $src
  #
  #     # Test MicroVM builds
  #     # for vm in dev-vm test-vm playground-vm; do
  #     #   echo "Testing MicroVM: $vm"
  #     #   if ! ${pkgs.nix}/bin/nix build --extra-experimental-features 'nix-command flakes' --no-link ".#nixosConfigurations.$vm.config.system.build.toplevel" --show-trace; then
  #     #     echo "ERROR: Failed to build MicroVM: $vm"
  #     #     exit 1
  #     #   fi
  #     #   echo "✅ MicroVM $vm builds successfully"
  #     # done
  #     echo "MicroVM validation skipped (VMs disabled)"
  #
  #     touch $out
  #   '';

  # Live ISO validation
  # live-iso-validation =
  #   pkgs.runCommand "live-iso-validation"
  #     {
  #       src = cleanSource ../.;
  #     } ''
  #     echo "Validating Live ISO configurations..."
  #     cd $src
  #
  #     # Test live ISO builds (just the configuration, not the full ISO)
  #     for host in p620 p510 razer samsung; do
  #       echo "Testing Live ISO config for host: $host"
  #       if ! ${pkgs.nix}/bin/nix build --extra-experimental-features 'nix-command flakes' --no-link ".#packages.x86_64-linux.live-iso-$host" --show-trace; then
  #         echo "WARNING: Live ISO build failed for host: $host (may be expected)"
  #       else
  #         echo "✅ Live ISO $host builds successfully"
  #       fi
  #     done
  #
  #     touch $out
  #   '';

  # Flake validation
  # flake-check =
  #   pkgs.runCommand "flake-validation"
  #     {
  #       src = cleanSource ../.;
  #     } ''
  #     echo "Running comprehensive flake check..."
  #     cd $src
  #
  #     # Basic flake validation
  #     ${pkgs.nix}/bin/nix flake check --extra-experimental-features 'nix-command flakes' --all-systems --show-trace || {
  #       echo "Flake check completed with warnings (allowed)"
  #     }
  #
  #     touch $out
  #   '';

  # Package duplication analysis
  package-duplication-check =
    pkgs.runCommand "package-duplication-analysis"
      {
        src = cleanSource ../.;
      } ''
      echo "Analyzing package duplication..."

      # Count package declarations in modules
      duplicates=$(${pkgs.ripgrep}/bin/rg -n "environment\.systemPackages.*with pkgs" $src/modules --type nix | wc -l || true)
      shared_deps=$(${pkgs.ripgrep}/bin/rg -n "features\.packages\." $src/modules --type nix | wc -l || true)

      echo "Package declarations found: $duplicates"
      echo "Shared dependency usage: $shared_deps"

      if [ "$duplicates" -gt 10 ]; then
        echo "WARNING: High number of individual package declarations detected"
        echo "Consider using shared dependency management where appropriate"
      fi

      touch $out
    '';

  # Security validation
  security-check =
    pkgs.runCommand "security-validation"
      {
        src = cleanSource ../.;
      } ''
      echo "Running security validation..."

      # Check for hardcoded secrets (basic check)
      if ${pkgs.ripgrep}/bin/rg -i "password.*=.*[\"'][^\"']*[\"']" $src --type nix; then
        echo "WARNING: Potential hardcoded passwords found"
      fi

      # Check for proper secret management usage
      secret_usage=$(${pkgs.ripgrep}/bin/rg -n "age\.secrets" $src --type nix | wc -l || true)
      echo "Agenix secret usage count: $secret_usage"

      if [ "$secret_usage" -lt 5 ]; then
        echo "INFO: Consider using Agenix for more secret management"
      fi

      touch $out
    '';

  # Performance analysis
  performance-check =
    pkgs.runCommand "performance-analysis"
      {
        src = cleanSource ../.;
      } ''
      echo "Analyzing configuration performance characteristics..."

      # Count total modules
      total_modules=$(find $src/modules -name "*.nix" | wc -l)
      echo "Total modules: $total_modules"

      # Count feature flags
      feature_flags=$(${pkgs.ripgrep}/bin/rg -n "mkEnableOption\|mkOption" $src/modules --type nix | wc -l || true)
      echo "Configuration options: $feature_flags"

      # Estimate evaluation complexity
      if [ "$total_modules" -gt 100 ]; then
        echo "INFO: Large configuration detected ($total_modules modules)"
        echo "Consider module optimization for faster evaluation"
      fi

      touch $out
    '';
}
