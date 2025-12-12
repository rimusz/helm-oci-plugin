#!/bin/bash

set -e

# Helm OCI Plugin using crane
# This plugin provides OCI registry operations for Helm charts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
CRANE_BINARY="$PLUGIN_DIR/bin/crane"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}INFO:${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}WARN:${NC} $1" >&2
}

log_error() {
    echo -e "${RED}ERROR:${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}SUCCESS:${NC} $1" >&2
}

# Check if crane is installed
check_crane() {
    if [[ ! -x "$CRANE_BINARY" ]]; then
        log_error "Crane binary not found at $CRANE_BINARY"
        log_info "Run 'helm plugin update oci' to install crane"
        exit 1
    fi
}

# Get Helm version (v3 or v4)
get_helm_version() {
    local helm_version
    helm_version=$(helm version --short 2>/dev/null | grep -o 'v[0-9]' | head -1)
    echo "$helm_version"
}

# List repositories in an OCI registry
list_repos() {
    local registry="$1"
    local username="$2"
    local password="$3"

    if [[ -z "$registry" ]]; then
        log_error "Registry URL is required"
        echo "Usage: helm oci list <registry> [--username <username>] [--password <password>]"
        exit 1
    fi

    check_crane

    log_info "Listing repositories in registry: $registry"

    # Build crane command with authentication if provided
    local crane_cmd=("$CRANE_BINARY" "catalog" "$registry")

    if [[ -n "$username" ]] && [[ -n "$password" ]]; then
        crane_cmd+=("--username" "$username" "--password" "$password")
    fi

    # Execute crane catalog command
    if "${crane_cmd[@]}"; then
        log_success "Successfully listed repositories"
    else
        log_error "Failed to list repositories"
        exit 1
    fi
}

# Search for Helm charts in an OCI registry
search_charts() {
    local registry="$1"
    local pattern="$2"
    local username="$3"
    local password="$4"

    if [[ -z "$registry" ]]; then
        log_error "Registry URL is required"
        echo "Usage: helm oci search <registry> [pattern] [--username <username>] [--password <password>]"
        exit 1
    fi

    check_crane

    # Parse registry and pattern from input
    # If registry contains '/', split it into registry and pattern
    local is_specific_repo=false
    if [[ "$registry" == */* ]] && [[ -z "$pattern" ]]; then
        # Extract registry (everything before first /) and pattern (everything after)
        local registry_part="${registry%%/*}"
        local path_part="${registry#*/}"
        registry="$registry_part"
        pattern="$path_part"
        is_specific_repo=true
        log_info "Parsed registry: $registry, specific repository: $pattern"
    else
        log_info "Searching for Helm charts in registry: $registry"
    fi

    # If searching for a specific repository, handle it directly
    if [[ "$is_specific_repo" == true ]]; then
        log_info "Searching for specific repository: $pattern"

        # Try to list tags for the specific repository
        local tags_cmd=("$CRANE_BINARY" "ls" "$registry/$pattern")
        if [[ -n "$username" ]] && [[ -n "$password" ]]; then
            tags_cmd+=("--username" "$username" "--password" "$password")
        fi

        log_info "Running: ${tags_cmd[*]}"
        local tags
        if tags=$("${tags_cmd[@]}" 2>/dev/null); then
            printf "%-50s %-20s\n" "REPOSITORY" "TAGS"
            printf "%-50s %-20s\n" "$(printf '%.0s-' {1..50})" "$(printf '%.0s-' {1..20})"

            # Get first few tags for display
            local tag_list
            tag_list=$(echo "$tags" | head -3 | tr '\n' ',' | sed 's/,$//')
            printf "%-50s %-20s\n" "$pattern" "$tag_list"

            log_success "Search completed"
        else
            log_error "Failed to get tags for repository: $registry/$pattern"
            log_error "Command failed: ${tags_cmd[*]}"
            log_error "This registry may require authentication. Try:"
            log_error "  helm oci search $registry/$pattern --username <username> --password <password>"
            exit 1
        fi
        return
    fi

    # Original logic for searching all repositories with optional pattern
    # Get all repositories first
    local repos
    local crane_cmd=("$CRANE_BINARY" "catalog" "$registry")

    if [[ -n "$username" ]] && [[ -n "$password" ]]; then
        crane_cmd+=("--username" "$username" "--password" "$password")
    fi

    log_info "Running: ${crane_cmd[*]}"
    if ! repos=$("${crane_cmd[@]}"); then
        log_error "Failed to get repository list from registry"
        log_error "Command failed: ${crane_cmd[*]}"
        log_error "This registry may require authentication. Try:"
        log_error "  helm oci search $registry --username <username> --password <password>"
        log_error "Or ensure your Docker config (~/.docker/config.json) has credentials for $registry"
        exit 1
    fi

    # Filter repositories based on pattern (if provided)
    local filtered_repos=()
    while IFS= read -r repo; do
        if [[ -z "$pattern" ]] || [[ "$repo" =~ $pattern ]]; then
            filtered_repos+=("$repo")
        fi
    done <<< "$repos"

    if [[ ${#filtered_repos[@]} -eq 0 ]]; then
        log_warn "No repositories found matching pattern: ${pattern:-'*'}"
        return
    fi

    log_info "Found ${#filtered_repos[@]} repositories"

    # For each repository, try to get tags (versions)
    printf "%-50s %-20s\n" "REPOSITORY" "TAGS"
    printf "%-50s %-20s\n" "$(printf '%.0s-' {1..50})" "$(printf '%.0s-' {1..20})"

    for repo in "${filtered_repos[@]}"; do
        local tags_cmd=("$CRANE_BINARY" "ls" "$registry/$repo")
        if [[ -n "$username" ]] && [[ -n "$password" ]]; then
            tags_cmd+=("--username" "$username" "--password" "$password")
        fi

        local tags
        if tags=$("${tags_cmd[@]}" 2>/dev/null); then
            # Get first few tags for display
            local tag_list
            tag_list=$(echo "$tags" | head -3 | tr '\n' ',' | sed 's/,$//')
            printf "%-50s %-20s\n" "$repo" "$tag_list"
        else
            printf "%-50s %-20s\n" "$repo" "N/A"
        fi
    done

    log_success "Search completed"
}

# Inspect chart metadata
inspect_chart() {
    local chart_ref="$1"
    local username="$2"
    local password="$3"

    if [[ -z "$chart_ref" ]]; then
        log_error "Chart reference is required"
        echo "Usage: helm oci inspect <chart-ref> [--username <username>] [--password <password>]"
        echo "Example: helm oci inspect registry.example.com/mychart:1.0.0"
        exit 1
    fi

    check_crane

    log_info "Inspecting chart: $chart_ref"

    # Build crane inspect command
    local inspect_cmd=("$CRANE_BINARY" "inspect" "$chart_ref")

    if [[ -n "$username" ]] && [[ -n "$password" ]]; then
        inspect_cmd+=("--username" "$username" "--password" "$password")
    fi

    log_info "Running: ${inspect_cmd[*]}"
    if "${inspect_cmd[@]}"; then
        log_success "Chart inspection completed"
    else
        log_error "Failed to inspect chart: $chart_ref"
        exit 1
    fi
}

# Show plugin help
show_help() {
    cat << EOF
Helm OCI Plugin v0.1.0

This plugin provides OCI registry operations for Helm charts using Google crane.

USAGE:
  helm oci <command> [arguments...]

COMMANDS:
  list <registry> [--username <username>] [--password <password>]
    List all repositories in the specified OCI registry

  search <registry> [pattern] [--username <username>] [--password <password>]
    Search for Helm charts in the specified OCI registry. If registry contains a path (registry/repo), shows tags for that specific repository. Otherwise, lists all repositories optionally filtered by pattern.

  inspect <chart-ref> [--username <username>] [--password <password>]
    Show detailed metadata and configuration for a chart

  help
    Show this help message

ARGUMENTS:
  registry    The OCI registry URL (e.g., registry.example.com) or full registry/repository path (e.g., registry.example.com/repo/chart)
  pattern     Optional regex pattern to filter repository names when searching all repos (ignored when searching specific repo)
  username    Optional username for registry authentication
  password    Optional password for registry authentication

EXAMPLES:
  # List all repositories in a registry
  helm oci list registry.example.com

  # List repositories with authentication
  helm oci list registry.example.com --username myuser --password mypass

  # Search for charts containing 'nginx'
  helm oci search registry.example.com nginx

  # Search with authentication
  helm oci search registry.example.com --username myuser --password mypass

INSTALLATION:
  helm plugin install https://github.com/your-org/helm-oci-plugin
  helm plugin update oci

DEPENDENCIES:
  This plugin automatically installs Google crane binary for registry operations.
EOF
}

# Parse command line arguments
parse_args() {
    local command=""
    local arg1=""
    local arg2=""
    local username=""
    local password=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            list|search|inspect)
                command="$1"
                arg1="$2"
                arg2="$3"
                shift 3
                ;;
            --username)
                username="$2"
                shift 2
                ;;
            --password)
                password="$2"
                shift 2
                ;;
            help|-h|--help)
                show_help
                exit 0
                ;;
            *)
                if [[ -z "$command" ]]; then
                    log_error "Unknown command: $1"
                    show_help
                    exit 1
                else
                    log_error "Unexpected argument: $1"
                    show_help
                    exit 1
                fi
                ;;
        esac
    done

    # If no command provided, show help
    if [[ -z "$command" ]]; then
        show_help
        exit 0
    fi

    # Execute the appropriate command
    case $command in
        list)
            list_repos "$arg1" "$username" "$password"
            ;;
        search)
            search_charts "$arg1" "$arg2" "$username" "$password"
            ;;
        inspect)
            inspect_chart "$arg1" "$username" "$password"
            ;;
        "")
            log_error "No command specified"
            show_help
            exit 1
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Main function
main() {
    local helm_version
    helm_version=$(get_helm_version)

    if [[ "$helm_version" != "v3" ]] && [[ "$helm_version" != "v4" ]]; then
        log_warn "Helm version detection failed or unsupported version. Assuming v3 compatibility."
    else
        log_info "Detected Helm $helm_version"
    fi

    parse_args "$@"
}

# Run main function with all arguments
main "$@"
