# Helm OCI Plugin

A Helm plugin that provides OCI registry operations using Google crane, enabling you to list and search for Helm charts in OCI registries.

## Features

- **List Repositories**: List all repositories in an OCI registry
- **Search Charts**: Search for Helm charts with optional pattern matching
- **Inspect Charts**: View detailed chart metadata and configuration
- **Authentication Support**: Support for username/password authentication
- **Cross-Platform**: Works on Linux and macOS (uses Homebrew on macOS)
- **Helm Compatible**: Compatible with both Helm v3 and v4
- **Smart Installation**: Uses existing crane if available, otherwise installs automatically

## Installation

### Prerequisites

- Helm v3 or v4 installed
- **macOS**: [Homebrew](https://brew.sh/) (required only if crane is not already installed)
- **Linux**: `curl` or `wget` (required only if crane is not already installed)

### Install the Plugin

```bash
# Install from a Git repository
helm plugin install https://github.com/rimusz/helm-oci-plugin --verify=false

# Or install from local directory
cd /path/to/helm-oci-plugin
helm plugin install .
```

### Update the Plugin

```bash
helm plugin update oci
```

This will also update the crane binary if a new version is available.

### Crane Installation

The plugin automatically handles crane installation:

- **If crane is already installed** (found in PATH): Uses the existing installation
- **macOS**: Installs crane using Homebrew if not found
- **Linux**: Downloads the latest crane binary if not found

No manual crane installation is required!

### Uninstall the Plugin

```bash
helm plugin uninstall oci
```

## Usage

### List Repositories

List all repositories in an OCI registry:

```bash
helm oci list <registry-url>
```

Examples:
```bash
# List repositories in a public registry
helm oci list registry.example.com

# List repositories with authentication
helm oci list registry.example.com --username myuser --password mypass

# List repositories in Docker Hub (use docker.io)
helm oci list docker.io
```

### Search Charts

Search for Helm charts in an OCI registry with optional pattern matching:

```bash
helm oci search <registry-url> [pattern]
```

Examples:
```bash
# Search all charts in a registry
helm oci search registry.example.com

# Search for charts containing 'nginx'
helm oci search registry.example.com nginx

# Search for charts starting with 'myapp'
helm oci search registry.example.com '^myapp'

# Search with authentication
helm oci search registry.example.com --username myuser --password mypass

# Search for a specific repository (shows tags for that specific repo)
helm oci search registry.example.com/myrepo/chart-name
```

### Inspect Charts

Show detailed metadata and configuration for a chart:

```bash
helm oci inspect <chart-reference>
```

Examples:
```bash
# Inspect chart metadata
helm oci inspect registry.example.com/mychart:1.0.0

# Inspect with authentication
helm oci inspect registry.example.com/mychart:1.0.0 --username myuser --password mypass
```

### Help

Show help and usage information:

```bash
helm oci help
```

## Output Format

### List Command Output
The `list` command outputs a simple list of repository names from the registry:

```
repo1
repo2
chart-name
another-chart
```

### Search Command Output
The `search` command provides a formatted table showing repositories and their available tags:

```
REPOSITORY                                         TAGS
-------------------------------------------------- --------------------
nginx                                              1.21.0,1.20.2,1.19.10
mysql                                              8.0.30,8.0.29,8.0.28
redis                                              7.0.5,7.0.4,7.0.3
```

## Authentication

The plugin supports basic authentication for private registries:

```bash
helm oci list registry.example.com --username <username> --password <password>
helm oci search registry.example.com --username <username> --password <password>
```

For enhanced security, consider using:
- Environment variables for credentials
- Docker config authentication
- Registry-specific authentication methods

## Examples

### Working with Public Registries

```bash
# Docker Hub
helm oci list docker.io
helm oci search docker.io nginx

# Google Container Registry
helm oci list gcr.io
helm oci search gcr.io

# GitHub Container Registry
helm oci list ghcr.io
helm oci search ghcr.io
```

### Working with Private Registries

```bash
# With authentication
helm oci list myregistry.com --username admin --password secret123
helm oci search myregistry.com myapp --username admin --password secret123

# Search for specific chart versions
helm oci search myregistry.com "^myapp-v[0-9]+\.[0-9]+$"
```

### CI/CD Integration

The plugin can be used in CI/CD pipelines:

```yaml
# GitHub Actions example
- name: List Helm charts
  run: |
    helm oci list ${{ secrets.REGISTRY_URL }} \
      --username ${{ secrets.REGISTRY_USER }} \
      --password ${{ secrets.REGISTRY_PASS }}

- name: Search for specific chart
  run: |
    helm oci search ${{ secrets.REGISTRY_URL }} myapp \
      --username ${{ secrets.REGISTRY_USER }} \
      --password ${{ secrets.REGISTRY_PASS }}
```

## Architecture

The plugin consists of:

- `plugin.yaml`: Plugin metadata and hooks
- `scripts/helm-oci.sh`: Main plugin script with command handling
- `scripts/install-crane.sh`: Installation script for crane binary
- `bin/crane`: Downloaded crane binary (created during installation)

## Dependencies

- **Google crane**: Automatically downloaded and installed
- **macOS**: [Homebrew](https://brew.sh/) (preferred installation method)
- **Linux**: `curl` or `wget` (for downloading crane binary)
- **Helm v3/v4**: For plugin framework

## Troubleshooting

### Common Issues

1. **"crane binary not found"**
   - Run `helm plugin update oci` to reinstall crane

2. **"Failed to download crane"**
   - Check internet connection
   - Verify curl/wget is installed
   - Check firewall settings

3. **"Authentication failed"**
   - Verify username and password
   - Check if registry requires token authentication
   - Try using Docker config authentication

4. **"Unknown command"**
   - Run `helm oci help` for available commands

5. **macOS/Homebrew issues**
   - Ensure Homebrew is installed and up to date: `brew update`
   - If brew installation fails, the plugin will fall back to downloading crane manually
   - Check that crane formula is available: `brew info crane`

### Debug Mode

Enable verbose logging by modifying the plugin scripts or checking crane verbose output.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on both Linux and macOS
5. Submit a pull request

## License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.

## Acknowledgments

- [Google go-containerregistry](https://github.com/google/go-containerregistry) for the crane tool
- [Helm](https://helm.sh/) for the plugin framework
