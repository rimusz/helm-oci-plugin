#!/bin/bash

set -e

# Install script for Google crane binary
# This script downloads and installs crane for use with the Helm OCI plugin

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$PLUGIN_DIR/bin"
CRANE_BINARY="$BIN_DIR/crane"

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

# Detect OS and architecture
detect_platform() {
    local os=""
    local arch=""

    case "$(uname -s)" in
        Linux)
            os="linux"
            ;;
        Darwin)
            os="darwin"
            ;;
        *)
            log_error "Unsupported OS: $(uname -s)"
            exit 1
            ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64)
            arch="amd64"
            ;;
        arm64|aarch64)
            arch="arm64"
            ;;
        *)
            log_error "Unsupported architecture: $(uname -m)"
            exit 1
            ;;
    esac

    echo "${os}-${arch}"
}

# Get latest crane version from GitHub releases
get_latest_version() {
    local api_url="https://api.github.com/repos/google/go-containerregistry/releases/latest"

    log_info "Fetching latest crane version from GitHub..."

    # Try to get version using curl
    local version=""
    if command -v curl >/dev/null 2>&1; then
        version=$(curl -s "$api_url" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    elif command -v wget >/dev/null 2>&1; then
        version=$(wget -q -O - "$api_url" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    else
        log_error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi

    if [[ -z "$version" ]]; then
        log_warn "Could not fetch latest version. Using fallback version v0.19.0"
        version="v0.19.0"
    fi

    echo "$version"
}

# Check if brew is available on macOS
check_brew() {
    if [[ "$(uname -s)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Install crane using brew (macOS only)
install_crane_brew() {
    log_info "Installing crane using Homebrew"

    # Create bin directory if it doesn't exist
    mkdir -p "$BIN_DIR"

    # Use brew to install crane
    if ! brew install crane; then
        log_error "Failed to install crane using brew"
        return 1
    fi

    # Find the brew-installed crane binary
    local brew_crane_path
    brew_crane_path=$(brew --prefix crane)/bin/crane 2>/dev/null || brew_crane_path=""

    if [[ -z "$brew_crane_path" ]] || [[ ! -x "$brew_crane_path" ]]; then
        # Fallback: try to find crane in PATH
        brew_crane_path=$(which crane 2>/dev/null || echo "")
    fi

    if [[ -z "$brew_crane_path" ]] || [[ ! -x "$brew_crane_path" ]]; then
        log_error "Could not find brew-installed crane binary"
        return 1
    fi

    # Create symlink to the brew-installed crane
    if ! ln -sf "$brew_crane_path" "$CRANE_BINARY"; then
        log_error "Failed to create symlink to crane binary"
        return 1
    fi

    # Verify installation
    if "$CRANE_BINARY" version >/dev/null 2>&1; then
        log_success "Crane installed successfully via Homebrew"
        "$CRANE_BINARY" version
        return 0
    else
        log_error "Crane installation verification failed"
        return 1
    fi
}

# Download and install crane (fallback method)
install_crane_download() {
    local platform
    platform=$(detect_platform)
    local version
    version=$(get_latest_version)

    log_info "Installing crane $version for $platform via download"

    # Create bin directory if it doesn't exist
    mkdir -p "$BIN_DIR"

    # Download URL for crane binary
    local download_url="https://github.com/google/go-containerregistry/releases/download/${version}/go-containerregistry_${platform}.tar.gz"
    local temp_dir
    temp_dir=$(mktemp -d)
    local archive_path="$temp_dir/crane.tar.gz"

    log_info "Downloading crane from $download_url"

    # Download the archive
    if command -v curl >/dev/null 2>&1; then
        if ! curl -L -o "$archive_path" "$download_url"; then
            log_error "Failed to download crane archive"
            rm -rf "$temp_dir"
            exit 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -O "$archive_path" "$download_url"; then
            log_error "Failed to download crane archive"
            rm -rf "$temp_dir"
            exit 1
        fi
    else
        log_error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi

    # Extract crane binary
    log_info "Extracting crane binary..."
    if ! tar -xzf "$archive_path" -C "$temp_dir"; then
        log_error "Failed to extract crane archive"
        rm -rf "$temp_dir"
        exit 1
    fi

    # Find and install crane binary
    local extracted_crane
    extracted_crane=$(find "$temp_dir" -name "crane" -type f 2>/dev/null | head -1)

    if [[ -z "$extracted_crane" ]]; then
        log_error "Crane binary not found in archive"
        rm -rf "$temp_dir"
        exit 1
    fi

    # Install crane binary
    if ! mv "$extracted_crane" "$CRANE_BINARY"; then
        log_error "Failed to install crane binary"
        rm -rf "$temp_dir"
        exit 1
    fi

    # Make crane executable
    chmod +x "$CRANE_BINARY"

    # Cleanup
    rm -rf "$temp_dir"

    # Verify installation
    if "$CRANE_BINARY" version >/dev/null 2>&1; then
        log_success "Crane $version installed successfully via download"
        "$CRANE_BINARY" version
    else
        log_error "Crane installation verification failed"
        exit 1
    fi
}

# Install crane using platform-specific method
install_crane() {
    local os_type
    os_type=$(uname -s)

    case "$os_type" in
        Darwin)
            # macOS - use brew
            log_info "Installing crane on macOS using Homebrew..."
            if ! install_crane_brew; then
                log_error "Failed to install crane using Homebrew"
                exit 1
            fi
            ;;
        Linux)
            # Linux - download binary
            log_info "Installing crane on Linux via download..."
            if ! install_crane_download; then
                log_error "Failed to download and install crane"
                exit 1
            fi
            ;;
        *)
            log_error "Unsupported operating system: $os_type"
            exit 1
            ;;
    esac
}

# Check if crane is available (either in plugin bin or system PATH)
check_crane_available() {
    # First check if we already have crane in plugin bin
    if [[ -x "$CRANE_BINARY" ]] && "$CRANE_BINARY" version >/dev/null 2>&1; then
        local current_version
        current_version=$("$CRANE_BINARY" version 2>/dev/null | head -1 || echo "unknown")
        log_info "Crane already available in plugin: $current_version"
        return 0
    fi

    # Check if crane is available in system PATH
    if command -v crane >/dev/null 2>&1; then
        log_info "Crane found in system PATH"
        # Create symlink to system crane
        mkdir -p "$BIN_DIR"
        local system_crane_path
        system_crane_path=$(which crane)
        if ln -sf "$system_crane_path" "$CRANE_BINARY"; then
            log_info "Created symlink to system crane: $system_crane_path"
            return 0
        else
            log_warn "Failed to create symlink to system crane"
            return 1
        fi
    fi

    log_info "Crane not found in system PATH"
    return 1
}

# Main installation function
main() {
    log_info "Helm OCI Plugin - Checking/Installing crane dependency"

    if ! check_crane_available; then
        log_info "Crane not available, proceeding with installation..."
        install_crane
    else
        log_info "Crane is available and ready to use"
    fi

    log_success "Crane setup completed"
}

# Run main function
main "$@"
