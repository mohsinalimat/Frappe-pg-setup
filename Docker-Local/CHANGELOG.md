# Changelog - Docker-Local

## [1.2.0] - 2026-05-14

### 🚀 New Features
- **Multiple Custom Apps**: Script now loops — you can install any number of custom apps in a single run, not just one
- **Private Repository Support**: New SSH key workflow for private GitHub repos — auto-detects or generates an SSH key, displays the public key to add to GitHub, tests the connection, and mounts the key into the `create-site` container
- **Auto HTTPS→SSH URL Conversion**: When you mark an app as private, any `https://github.com/…` URL is automatically converted to `git@github.com:…` so authentication works correctly

### 🐛 Bug Fixes
- **Custom App URL Parsing (Critical)**: Fixed token separator from `:` to `|` — previously `https://github.com/org/app.git` was split by the colon in `://`, causing `bench get-app` to receive only `https` as the URL instead of the full path. All custom apps were silently broken.
- **pip Editable Install**: Fixed `pip install -e apps/a apps/b` — only the first app was installed in editable mode. Now each app gets its own `-e` flag: `pip install -e apps/a -e apps/b -e apps/c`.

### 🔧 Improvements
- **PostgreSQL**: `frappe_pg` is now updated via `git pull` on re-runs (previously it was only cloned once and never updated)

---

## [1.1.0] - 2024-12-19

### 🚀 New Features
- **Smart Port Detection**: Scripts now automatically detect and display custom Traefik ports
- **Enhanced Documentation**: Comprehensive README.md and Quick Reference guides
- **Improved User Experience**: Better port information display throughout the process
- **Screenshot Integration**: Documentation now includes helper screenshots

### 🔧 Improvements
- **Port Display Logic**: Fixed inconsistent port information display
- **URL Generation**: Centralized URL generation with proper port handling
- **Configuration Loading**: Better handling of local Traefik configuration
- **User Feedback**: More informative messages about port usage

### 🐛 Bug Fixes
- **Port Detection Bug**: Fixed issue where custom ports (e.g., 8081) weren't shown in final URLs
- **URL Consistency**: All URL displays now show the correct port information
- **Configuration Persistence**: Local config is now properly loaded and used throughout the process

### 📚 Documentation
- **README.md**: Comprehensive documentation with screenshots and examples
- **QUICK_REFERENCE.md**: Quick command reference for common operations
- **CHANGELOG.md**: This file to track changes and improvements
- **Screenshot Integration**: Helper screenshots properly referenced in documentation

### 🎯 Technical Improvements
- **Code Structure**: Improved variable handling and URL generation
- **Error Handling**: Better error messages and user guidance
- **Port Logic**: Centralized port detection and display logic
- **User Interface**: Clearer information display at each step

## [1.0.0] - Initial Release

### ✨ Initial Features
- **generate_frappe_docker_local.sh**: Optimized Frappe/ERPNext site generation
- **docker-manager-local.sh**: Comprehensive container management tool
- **Optimized Architecture**: 4 containers instead of 9 for better performance
- **Supervisor Integration**: All Frappe processes managed in single container
- **Local Development**: Optimized for local development environments

### 🔧 Core Functionality
- **Site Generation**: Automated Frappe/ERPNext site creation
- **Container Management**: Start, stop, restart, and manage containers
- **Process Control**: Manage Frappe processes via Supervisor
- **Network Management**: Handle Docker networks and connectivity
- **Log Management**: View and manage container logs

### 🌐 Features
- **Traefik Integration**: Automatic reverse proxy setup
- **Hosts File Management**: Auto-add domains to system hosts file
- **Port Configuration**: Support for custom HTTP/HTTPS ports
- **Localhost Support**: Built-in support for .localhost domains

---

## 🔮 Future Plans

### Planned Features
- **SSL Support**: Local HTTPS with self-signed certificates
- **Multi-Site Management**: Better handling of multiple Frappe sites
- **Backup/Restore**: Automated backup and restore functionality
- **Performance Monitoring**: Built-in resource usage monitoring
- **Plugin System**: Extensible architecture for additional features

### Improvements
- **UI Enhancement**: More intuitive user interface
- **Configuration Management**: Better configuration file handling
- **Error Recovery**: Automated error recovery and troubleshooting
- **Integration**: Better integration with other Docker tools

---

## 📝 How to Update

### From Previous Versions
1. **Backup**: Backup your current configuration files
2. **Update Scripts**: Replace old scripts with new versions
3. **Test**: Test with a new site to ensure compatibility
4. **Migrate**: Migrate existing sites if needed

### Configuration Changes
- **Port Detection**: Now automatically detects custom ports
- **URL Display**: All URLs now show correct port information
- **Better Feedback**: Improved user feedback throughout the process

---

## 🤝 Contributing

### Reporting Issues
- Check existing issues first
- Provide detailed error messages
- Include system information
- Attach relevant logs

### Suggesting Features
- Describe the use case
- Explain the benefit
- Provide examples if possible
- Consider implementation complexity

### Code Contributions
- Follow existing code style
- Add tests for new features
- Update documentation
- Test thoroughly before submitting

---

**Note**: This changelog tracks significant changes to the Docker-Local tools. For detailed technical changes, refer to the git commit history.
