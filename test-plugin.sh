#!/bin/bash

# Test script for Helm OCI Plugin
# This script validates the plugin installation and basic functionality

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}INFO:${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}WARN:${NC} $1"
}

log_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

log_success() {
    echo -e "${GREEN}SUCCESS:${NC} $1"
}

# Test plugin structure
test_plugin_structure() {
    log_info "Testing plugin structure..."

    # Check required files exist
    local required_files=(
        "plugin.yaml"
        "scripts/helm-oci.sh"
        "scripts/install-crane.sh"
        "README.md"
    )

    for file in "${required_files[@]}"; do
        if [[ ! -f "$PLUGIN_DIR/$file" ]]; then
            log_error "Required file missing: $file"
            return 1
        fi
    done

    # Check scripts are executable
    if [[ ! -x "$PLUGIN_DIR/scripts/helm-oci.sh" ]]; then
        log_error "helm-oci.sh is not executable"
        return 1
    fi

    if [[ ! -x "$PLUGIN_DIR/scripts/install-crane.sh" ]]; then
        log_error "install-crane.sh is not executable"
        return 1
    fi

    log_success "Plugin structure is valid"
    return 0
}

# Test plugin.yaml syntax
test_plugin_yaml() {
    log_info "Testing plugin.yaml syntax..."

    # Basic YAML structure check - ensure required fields exist
    if grep -q "^name:" "$PLUGIN_DIR/plugin.yaml" && \
       grep -q "^version:" "$PLUGIN_DIR/plugin.yaml" && \
       grep -q "^command:" "$PLUGIN_DIR/plugin.yaml"; then
        log_success "plugin.yaml contains required fields"
        return 0
    else
        log_error "plugin.yaml missing required fields"
        return 1
    fi
}

# Test help command
test_help_command() {
    log_info "Testing help command..."

    if "$PLUGIN_DIR/scripts/helm-oci.sh" help >/dev/null 2>&1; then
        log_success "Help command works"
        return 0
    else
        log_error "Help command failed"
        return 1
    fi
}

# Test install script (without actually downloading)
test_install_script() {
    log_info "Testing install script structure..."

    # Test that the install script can detect platform without network operations
    # We'll mock the network call by checking the script logic

    # Check if script has platform detection logic
    if grep -q "detect_platform" "$PLUGIN_DIR/scripts/install-crane.sh"; then
        log_success "Install script has platform detection"
    else
        log_error "Install script missing platform detection"
        return 1
    fi

    # Check if script has download logic
    if grep -q "download_url" "$PLUGIN_DIR/scripts/install-crane.sh"; then
        log_success "Install script has download logic"
    else
        log_error "Install script missing download logic"
        return 1
    fi

    log_success "Install script structure is valid"
    return 0
}

# Main test function
main() {
    log_info "Starting Helm OCI Plugin tests..."

    local tests_passed=0
    local total_tests=0

    # Test plugin structure
    ((total_tests++))
    if test_plugin_structure; then
        ((tests_passed++))
    fi

    # Test plugin.yaml
    ((total_tests++))
    if test_plugin_yaml; then
        ((tests_passed++))
    fi

    # Test help command
    ((total_tests++))
    if test_help_command; then
        ((tests_passed++))
    fi

    # Test install script
    ((total_tests++))
    if test_install_script; then
        ((tests_passed++))
    fi

    # Summary
    echo
    log_info "Test Results: $tests_passed/$total_tests tests passed"

    if [[ $tests_passed -eq $total_tests ]]; then
        log_success "All tests passed! The plugin is ready for installation."
        echo
        log_info "To install the plugin locally for testing:"
        echo "  cd $PLUGIN_DIR"
        echo "  helm plugin install ."
        echo
        log_info "To test the plugin:"
        echo "  helm oci help"
        echo "  helm oci list docker.io  # (may require authentication)"
        return 0
    else
        log_error "Some tests failed. Please check the errors above."
        return 1
    fi
}

# Run main function
main "$@"
