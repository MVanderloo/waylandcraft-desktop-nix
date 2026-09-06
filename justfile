set shell := ["bash", "-euo", "pipefail", "-c"]

flake := "path:."

# List the available project commands.
default:
    @just --list

# Start the pinned manual Waylandcraft demo from the active local VT.
demo:
    nix run --no-update-lock-file {{flake}}#demo

# Run every normal flake check (the VM is deliberately separate).
check:
    nix flake check {{flake}} --no-update-lock-file --print-build-logs

# Build and execute the complete NixOS supervision VM test.
supervision-vm:
    nix build --no-update-lock-file {{flake}}#supervision-vm --print-build-logs

# Run formatting, normal checks, and the full NixOS VM test.
check-all: format-check check supervision-vm

# Test pinned Cage and a native Wayland client directly from the active local VT.
tty-smoke:
    ./scripts/tty-cage-smoke

# Print a read-only host and session diagnostic report.
diagnose:
    nix run --no-update-lock-file {{flake}}#diagnose

# Include recent display-manager, Minecraft, and coredump logs in the report.
diagnose-logs:
    nix run --no-update-lock-file {{flake}}#diagnose -- --logs

# Format every Nix source with the flake-pinned formatter.
format:
    nix fmt -- $(git ls-files -co --exclude-standard '*.nix')

# Check Nix formatting and whitespace without modifying files.
format-check:
    nix fmt -- --check $(git ls-files -co --exclude-standard '*.nix')
    git diff --check
