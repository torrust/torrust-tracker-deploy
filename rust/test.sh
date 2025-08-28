#!/bin/bash

# Test script for the Rust implementation
# Usage: ./test.sh [unit] [build] [all]

set -e

# Change to Rust directory
cd "$(dirname "$0")"

# Default to no tests selected
run_unit=false
run_build=false

# If no arguments provided, show usage
if [ $# -eq 0 ]; then
    echo "Usage: $0 [unit] [build] [all]"
    echo ""
    echo "Options:"
    echo "  unit   - Run unit tests"
    echo "  build  - Build the application"
    echo "  all    - Run all tests and build"
    echo ""
    echo "Examples:"
    echo "  $0 all                    # Run all tests and build"
    echo "  $0 unit build             # Run unit tests and build"
    echo "  $0 unit                   # Run unit tests only"
    exit 1
fi

# Parse arguments
for arg in "$@"; do
    case $arg in
        unit)
            run_unit=true
            ;;
        build)
            run_build=true
            ;;
        all)
            run_unit=true
            run_build=true
            ;;
        *)
            echo "Unknown argument: $arg"
            echo "Valid options: unit, build, all"
            exit 1
            ;;
    esac
done

echo "Running Rust tests and builds..."

if [ "$run_unit" = true ]; then
    echo "=== Running Unit Tests ==="
    cargo test
    echo ""
    
    echo "=== Running Clippy (Linter) ==="
    cargo clippy -- -D warnings
    echo ""
    
    echo "=== Checking Code Format ==="
    cargo fmt -- --check
    echo ""
fi

if [ "$run_build" = true ]; then
    echo "=== Building Debug Version ==="
    cargo build
    echo ""
    
    echo "=== Building Release Version ==="
    cargo build --release
    echo ""
    
    echo "=== Testing CLI Help ==="
    ./target/release/torrust-deploy --help
    echo ""
    
    echo "=== Testing Provision Help ==="
    ./target/release/torrust-deploy provision --help
    echo ""
fi

echo "✅ All selected tests and builds completed successfully!"
