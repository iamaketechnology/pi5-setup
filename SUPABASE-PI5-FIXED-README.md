# Supabase Pi 5 Fixed Installation Script

## Overview

This is a completely rewritten, production-ready Supabase deployment script specifically designed for Raspberry Pi 5 ARM64 architecture. It addresses all the critical issues found in previous versions and provides a robust, reliable installation experience.

## Critical Issues Fixed

### ✅ PostgreSQL Version Compatibility
- **Issue**: PostgreSQL 15 Alpine doesn't support modern "IF NOT EXISTS" syntax for CREATE ROLE/TYPE
- **Fix**: Upgraded to PostgreSQL 16.4 Alpine with full modern syntax support
- **Solution**: Proper fallback logic using DO blocks and exception handling

### ✅ Health Check Failures
- **Issue**: Health checks failing with "curl: executable file not found in $PATH"
- **Fix**: Replaced curl with wget (available in all Alpine images)
- **Solution**: Proper health check commands for each service type

### ✅ Database Structure Issues
- **Issue**: Missing auth.factor_type enum, incomplete schema initialization
- **Fix**: Comprehensive database initialization with proper schema creation
- **Solution**: Separate SQL scripts with proper error handling

### ✅ Container Restart Loops
- **Issue**: Auth and Realtime services constantly restarting due to connection issues
- **Fix**: Proper service dependencies, staged startup, encryption key fixes
- **Solution**: ARM64-optimized encryption keys and connection strings

### ✅ ARM64 Optimization
- **Issue**: Generic configuration not optimized for Pi 5 ARM64 architecture
- **Fix**: Platform-specific settings, resource limits, and Pi 5 optimizations
- **Solution**: Proper memory allocation and CPU limits for 16GB Pi 5

## Features

### 🔧 Production-Ready Architecture
- **PostgreSQL 16.4**: Latest stable with full ARM64 support
- **Staged Deployment**: Services start in proper dependency order
- **Health Monitoring**: Comprehensive health checks with timeouts
- **Error Handling**: Graceful error recovery with rollback mechanisms
- **Resource Management**: Optimized for Pi 5 16GB RAM configuration

### 🛠️ Management Tools
- **Health Check**: `./scripts/health-check.sh` - Monitor all services
- **Logs Viewer**: `./scripts/logs.sh <service>` - View service logs
- **Service Restart**: `./scripts/restart.sh [service]` - Restart services
- **Backup System**: `./scripts/backup.sh` - Create full backups
- **Update Manager**: `./scripts/update.sh` - Update to latest images

### 🔐 Security Features
- **Secure Secrets**: Cryptographically secure password generation
- **Proper Permissions**: Correct file and directory permissions
- **Environment Protection**: Secure .env file handling (600 permissions)
- **ARM64 Encryption**: Proper encryption key lengths for ARM64

### 📊 Validation System
- **6-Point Validation**: Comprehensive installation verification
- **Service Health**: Real-time service status monitoring
- **Connectivity Tests**: Network and API endpoint validation
- **Database Schema**: Schema and table structure verification

## Prerequisites

### System Requirements
- **Hardware**: Raspberry Pi 5 (16GB RAM recommended, 4GB minimum)
- **OS**: Raspberry Pi OS Bookworm 64-bit (ARM64)
- **Storage**: 10GB+ free space
- **Network**: Internet connection for Docker image downloads

### Page Size Check (Critical)
```bash
getconf PAGESIZE
```
**Must return 4096**. If it returns 16384:
1. Add `kernel=kernel8.img` to `/boot/firmware/config.txt`
2. Reboot: `sudo reboot`
3. Verify: `getconf PAGESIZE` should show 4096

### Docker Prerequisites
This script requires Docker and Docker Compose v2 to be installed (typically from Week 1 setup):
```bash
docker --version
docker compose version
```

## Installation

### Basic Installation
```bash
# Download the script
wget https://raw.githubusercontent.com/your-repo/pi5-setup/main/setup-week2-supabase-pi5-fixed.sh

# Make executable
chmod +x setup-week2-supabase-pi5-fixed.sh

# Run installation
sudo ./setup-week2-supabase-pi5-fixed.sh
```

### Advanced Options
```bash
# Custom port (default: 8001)
sudo SUPABASE_PORT=8002 ./setup-week2-supabase-pi5-fixed.sh

# Force cleanup on failure
sudo FORCE_CLEANUP=yes ./setup-week2-supabase-pi5-fixed.sh

# Extended health check timeout (default: 300s)
sudo HEALTH_CHECK_TIMEOUT=600 ./setup-week2-supabase-pi5-fixed.sh
```

## Post-Installation

### Service Access
- **Supabase Studio**: http://your-pi-ip:3000
- **API Gateway**: http://your-pi-ip:8001
- **Edge Functions**: http://your-pi-ip:54321
- **PostgreSQL**: your-pi-ip:5432

### First Steps
1. **Access Studio**: Navigate to http://your-pi-ip:3000
2. **Create Organization**: Set up your first organization
3. **Create Project**: Create your first Supabase project
4. **Test API**: Use the API endpoints via the gateway

### Management Commands
```bash
cd /home/pi/stacks/supabase

# Check service health
./scripts/health-check.sh

# View logs for a specific service
./scripts/logs.sh realtime

# Restart a problematic service
./scripts/restart.sh auth

# Create backup
./scripts/backup.sh

# Update to latest images
./scripts/update.sh
```

## Troubleshooting

### Common Issues

#### Services Unhealthy
```bash
# Check which services are unhealthy
./scripts/health-check.sh

# View logs for unhealthy service
./scripts/logs.sh <service-name>

# Restart specific service
./scripts/restart.sh <service-name>
```

#### Database Connection Issues
```bash
# Test PostgreSQL directly
docker exec supabase-db pg_isready -U postgres

# Check database logs
./scripts/logs.sh db

# Verify database schema
docker exec supabase-db psql -U postgres -c "\\l"
```

#### Port Conflicts
```bash
# Check what's using ports
sudo netstat -tulpn | grep :3000
sudo netstat -tulpn | grep :8001

# Stop conflicting services before running script
```

### Log Files
- **Installation Log**: `/var/log/supabase-pi5-setup-3.0-fixed-YYYYMMDD_HHMMSS.log`
- **Service Logs**: Available via `./scripts/logs.sh <service>`

### Recovery Procedures

#### Complete Reset
```bash
cd /home/pi/stacks/supabase
docker compose down -v  # WARNING: Deletes all data
sudo rm -rf /home/pi/stacks/supabase
# Re-run installation script
```

#### Backup Restoration
```bash
# Restore from backup (if available)
./scripts/restore.sh ./backups/YYYYMMDD_HHMMSS/
```

## Architecture

### Service Stack
```
┌─────────────────┐
│  Studio (3000)  │  Web Interface
├─────────────────┤
│   Kong (8001)   │  API Gateway
├─────────────────┤
│ Auth │ REST │ RT │  Core Services
├─────────────────┤
│ Storage │ Meta  │  Additional Services
├─────────────────┤
│ PostgreSQL 16.4 │  Database
└─────────────────┘
```

### Key Improvements
1. **Staged Startup**: Services start in proper dependency order
2. **Health Monitoring**: Each service has proper health checks
3. **Error Recovery**: Automatic retry and fallback mechanisms
4. **Resource Limits**: Proper memory and CPU limits for Pi 5
5. **ARM64 Optimization**: Platform-specific configurations

## Version History

### v3.0-fixed (Current)
- Complete rewrite addressing all critical issues
- PostgreSQL 16.4 ARM64 with modern syntax support
- Fixed health checks using wget instead of curl
- Comprehensive database initialization
- ARM64-optimized encryption keys
- Production-ready error handling and rollback
- Management tools and validation system

### Previous Issues (Resolved)
- ❌ PostgreSQL 15 syntax compatibility
- ❌ Health check executable not found
- ❌ Missing auth.factor_type enum
- ❌ Restart loop issues
- ❌ ARM64 optimization gaps

## Support

### Getting Help
1. **Check Logs**: Review installation and service logs
2. **Run Health Check**: Use built-in diagnostic tools
3. **Consult Documentation**: Review Supabase official docs
4. **Community Support**: Check Pi 5 setup repository issues

### Reporting Issues
Please include:
- Installation log file
- Output of `./scripts/health-check.sh`
- Pi 5 hardware configuration
- OS version and kernel details

---

**Note**: This script is specifically designed for Raspberry Pi 5 ARM64 architecture and may not work correctly on other platforms without modifications.