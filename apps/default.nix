# Application entries for common workflows
{ pkgs, ... }:

{
  # Deployment applications
  deploy = pkgs.writeShellApplication {
    name = "nixos-deploy";
    runtimeInputs = with pkgs; [ openssh rsync nix ];
    text = ''
      #!/bin/bash
      
      show_help() {
        echo "NixOS Deployment Tool"
        echo ""
        echo "Usage: nix run .#deploy [COMMAND] [OPTIONS]"
        echo ""
        echo "Commands:"
        echo "  host <name>     Deploy to specific host (p620, p510, razer, dex5550, samsung)"
        echo "  all             Deploy to all hosts sequentially"
        echo "  parallel        Deploy to all hosts in parallel"
        echo "  quick <host>    Quick deploy (only if configuration changed)"
        echo "  emergency <host> Emergency deploy (skip tests)"
        echo ""
        echo "Examples:"
        echo "  nix run .#deploy host p620"
        echo "  nix run .#deploy parallel"
        echo "  nix run .#deploy quick razer"
        echo ""
      }
      
      case "''${1:-}" in
        host)
          if [ -z "''${2:-}" ]; then
            echo "Error: Host name required"
            show_help
            exit 1
          fi
          case "$2" in
            p620|p510|razer|dex5550|samsung)
              echo "Deploying to host: $2"
              just "$2"
              ;;
            *)
              echo "Error: Invalid host '$2'"
              echo "Available hosts: p620, p510, razer, dex5550, samsung"
              exit 1
              ;;
          esac
          ;;
        all)
          echo "Deploying to all hosts sequentially..."
          just deploy-all
          ;;
        parallel)
          echo "Deploying to all hosts in parallel..."
          just deploy-all-parallel
          ;;
        quick)
          if [ -z "''${2:-}" ]; then
            echo "Error: Host name required for quick deploy"
            exit 1
          fi
          echo "Quick deploying to host: $2"
          just quick-deploy "$2"
          ;;
        emergency)
          if [ -z "''${2:-}" ]; then
            echo "Error: Host name required for emergency deploy"
            exit 1
          fi
          echo "Emergency deploying to host: $2"
          just emergency-deploy "$2"
          ;;
        help|--help|-h)
          show_help
          ;;
        "")
          echo "Error: Command required"
          show_help
          exit 1
          ;;
        *)
          echo "Error: Unknown command '$1'"
          show_help
          exit 1
          ;;
      esac
    '';
  };

  # Testing applications  
  test = pkgs.writeShellApplication {
    name = "nixos-test";
    runtimeInputs = with pkgs; [ nix ];
    text = ''
      #!/bin/bash
      
      show_help() {
        echo "NixOS Testing Tool"
        echo ""
        echo "Usage: nix run .#test [COMMAND] [OPTIONS]"
        echo ""
        echo "Commands:"
        echo "  host <name>     Test specific host configuration"
        echo "  all             Test all host configurations sequentially"
        echo "  parallel        Test all hosts in parallel (faster)"
        echo "  quick           Quick test of all configurations"
        echo "  validate        Run comprehensive validation suite"
        echo "  syntax          Check Nix syntax only"
        echo ""
        echo "Examples:"
        echo "  nix run .#test host p620"
        echo "  nix run .#test parallel"
        echo "  nix run .#test validate"
        echo ""
      }
      
      case "''${1:-}" in
        host)
          if [ -z "''${2:-}" ]; then
            echo "Error: Host name required"
            show_help
            exit 1
          fi
          echo "Testing host configuration: $2"
          just test-host "$2"
          ;;
        all)
          echo "Testing all host configurations sequentially..."
          just test-all
          ;;
        parallel)
          echo "Testing all hosts in parallel..."
          just test-all-parallel
          ;;
        quick)
          echo "Running quick tests..."
          just quick-test
          ;;
        validate)
          echo "Running comprehensive validation suite..."
          just validate
          ;;
        syntax)
          echo "Checking Nix syntax..."
          just check-syntax
          ;;
        help|--help|-h)
          show_help
          ;;
        "")
          echo "Error: Command required"
          show_help
          exit 1
          ;;
        *)
          echo "Error: Unknown command '$1'"
          show_help
          exit 1
          ;;
      esac
    '';
  };

  # Live USB builder
  build-live = pkgs.writeShellApplication {
    name = "nixos-build-live";
    runtimeInputs = with pkgs; [ nix coreutils ];
    text = ''
      #!/bin/bash
      
      show_help() {
        echo "NixOS Live USB Builder"
        echo ""
        echo "Usage: nix run .#build-live [COMMAND] [HOST]"
        echo ""
        echo "Commands:"
        echo "  build <host>    Build live USB image for specific host"
        echo "  all             Build live USB images for all hosts"
        echo "  list            List available host configurations"
        echo ""
        echo "Available hosts: p620, p510, razer, dex5550, samsung"
        echo ""
        echo "Examples:"
        echo "  nix run .#build-live build p620"
        echo "  nix run .#build-live all"
        echo ""
      }
      
      available_hosts="p620 p510 razer dex5550 samsung"
      
      case "''${1:-}" in
        build)
          if [ -z "''${2:-}" ]; then
            echo "Error: Host name required"
            show_help
            exit 1
          fi
          
          if echo "$available_hosts" | grep -q "$2"; then
            echo "Building live USB image for: $2"
            nix build ".#packages.x86_64-linux.live-iso-$2" --show-trace
            if [ $? -eq 0 ]; then
              echo "✅ Live USB image built successfully for $2"
              echo "Image location: result/iso/"
            else
              echo "❌ Failed to build live USB image for $2"
              exit 1
            fi
          else
            echo "Error: Invalid host '$2'"
            echo "Available hosts: $available_hosts"
            exit 1
          fi
          ;;
        all)
          echo "Building live USB images for all hosts..."
          for host in $available_hosts; do
            echo "Building for $host..."
            nix build ".#packages.x86_64-linux.live-iso-$host" --show-trace || {
              echo "Warning: Failed to build for $host"
            }
          done
          echo "Batch build completed"
          ;;
        list)
          echo "Available host configurations:"
          for host in $available_hosts; do
            echo "  - $host"
          done
          ;;
        help|--help|-h)
          show_help
          ;;
        "")
          echo "Error: Command required"
          show_help
          exit 1
          ;;
        *)
          echo "Error: Unknown command '$1'"
          show_help
          exit 1
          ;;
      esac
    '';
  };

  # Development utilities
  dev-utils = pkgs.writeShellApplication {
    name = "nixos-dev-utils";
    runtimeInputs = with pkgs; [ nix git nixpkgs-fmt statix deadnix ];
    text = ''
      #!/bin/bash
      
      show_help() {
        echo "NixOS Development Utilities"
        echo ""
        echo "Usage: nix run .#dev-utils [COMMAND]"
        echo ""
        echo "Commands:"
        echo "  format          Format all Nix files"
        echo "  lint            Run linting checks"
        echo "  check-dead      Check for dead code"
        echo "  deps            Visualize dependencies"
        echo "  update          Update flake inputs"
        echo "  clean           Clean build artifacts"
        echo ""
        echo "Examples:"
        echo "  nix run .#dev-utils format"
        echo "  nix run .#dev-utils lint"
        echo ""
      }
      
      case "''${1:-}" in
        format)
          echo "Formatting all Nix files..."
          nixpkgs-fmt **/*.nix
          echo "✅ Formatting completed"
          ;;
        lint)
          echo "Running linting checks..."
          statix check --format=stderr || echo "Linting completed with warnings"
          ;;
        check-dead)
          echo "Checking for dead code..."
          deadnix
          ;;
        deps)
          echo "Visualizing dependencies..."
          nix-tree --derivation
          ;;
        update)
          echo "Updating flake inputs..."
          nix flake update
          echo "✅ Flake inputs updated"
          ;;
        clean)
          echo "Cleaning build artifacts..."
          nix-collect-garbage -d
          nix store gc
          echo "✅ Cleanup completed"
          ;;
        help|--help|-h)
          show_help
          ;;
        "")
          echo "Error: Command required"
          show_help
          exit 1
          ;;
        *)
          echo "Error: Unknown command '$1'"
          show_help
          exit 1
          ;;
      esac
    '';
  };
}