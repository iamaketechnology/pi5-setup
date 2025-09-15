# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository provides a 6-week progressive setup system for transforming a Raspberry Pi 5 (16GB) into a self-hosted development server. Each week builds upon the previous one, creating a complete mini data center.

## Architecture & Structure

### Progressive Weekly Setup System
- **Week 1**: Server foundation (Docker, security, monitoring)
- **Week 2**: Supabase ecosystem (PostgreSQL, Auth, Realtime, Studio)
- **Week 3**: External access & HTTPS (reverse proxy, tunneling)
- **Week 4**: Collaborative development (Git, code editors, CI/CD)
- **Week 5**: Personal cloud (file storage, backups)
- **Week 6**: Multimedia & IoT (media server, DNS, home automation)

### Script Architecture
Each setup script follows a modular pattern:
- Configuration variables at the top with sensible defaults
- Logging functions with colored output and file persistence
- Compatibility checks and system validation
- Modular functions for each installation component
- Comprehensive error handling with `set -euo pipefail`
- Summary reporting with next steps guidance

### Pi 5 Optimizations
Scripts include specific optimizations for Raspberry Pi 5:
- ARM64 architecture detection and validation
- GPU memory split configuration (default 128MB)
- Docker daemon optimization for ARM64
- Memory management (swappiness, file limits)
- Hardware interface enabling (I2C, SPI)
- Performance monitoring tools integration

## Commands

### Running Setup Scripts
```bash
# Week 1 - Server foundation
sudo MODE=beginner ./setup-week1.sh

# With custom configuration
sudo MODE=pro GPU_MEM_SPLIT=256 ENABLE_I2C=yes ./setup-week1.sh

# Pro mode with SSH hardening
sudo MODE=pro SSH_PORT=2222 ./setup-week1.sh
```

### Configuration Variables
Key environment variables for customization:
- `MODE`: `beginner` (default) or `pro` (includes SSH hardening)
- `GPU_MEM_SPLIT`: GPU memory allocation in MB (default: 128)
- `ENABLE_I2C`: Enable I2C interface (`yes`/`no`)
- `ENABLE_SPI`: Enable SPI interface (`yes`/`no`)
- `SSH_PORT`: Custom SSH port (default: 22)
- `LOG_FILE`: Custom log file path

### System Validation
```bash
# Check Docker functionality
docker run --rm hello-world

# Verify security services
sudo ufw status
sudo fail2ban-client status

# Monitor system resources
htop
iotop
```

### Log Management
Setup logs are saved to `/var/log/pi5-setup-week1.log` (or custom path) with timestamped entries for troubleshooting and audit trails.

## Development Guidelines

### Script Development Pattern
When creating new weekly setup scripts:
1. Follow the established modular function pattern
2. Include Pi 5 specific optimizations where relevant
3. Add comprehensive logging with the established log functions
4. Include compatibility and resource checks
5. Provide clear summary output with next steps
6. Use environment variables for configuration flexibility

### Security Considerations
- All scripts include firewall configuration (UFW)
- Fail2ban protection for SSH brute force attacks
- Optional SSH hardening in pro mode (key-only authentication)
- Automatic security updates enabled
- Docker daemon security configurations

### Hardware Integration
Scripts are designed to leverage Pi 5 capabilities:
- 16GB RAM optimization for containerized services
- ARM64 native Docker images when available
- GPIO interface support for IoT integration
- Hardware acceleration considerations for media services

## Known Issues & Solutions (Lessons Learned)

### Critical Supabase Installation Issues on Pi 5

#### 1. **Auth Service - `auth.factor_type` Missing**
**Problem:** GoTrue fails with "type auth.factor_type does not exist" during MFA migrations.
**Root Cause:** Incomplete auth schema initialization on ARM64/Pi 5.
**Solution:** Auto-create `auth.factor_type` ENUM type in setup script:
```sql
CREATE TYPE auth.factor_type AS ENUM ('totp', 'phone');
```

#### 2. **Realtime Service - Schema Migrations Failure**
**Problem:** Realtime crashes with "DBConnection.EncodeError: expected binary, got 20210706140551"
**Root Cause:** Realtime requires `realtime.schema_migrations` table with BIGINT version column, not TEXT.
**Solution:** Pre-create correct schema structure:
```sql
CREATE SCHEMA IF NOT EXISTS realtime;
CREATE TABLE realtime.schema_migrations(
  version BIGINT PRIMARY KEY,
  inserted_at TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NOW()
);
```

#### 3. **Realtime Configuration - Missing Environment Variables**
**Problem:** "APP_NAME not available" error on Elixir runtime.
**Root Cause:** Incomplete environment configuration for ARM64/Docker.
**Solution:** Complete environment variables including:
- `ERL_AFLAGS: "-proto_dist inet_tcp"` (critical for ARM64)
- `APP_NAME: supabase_realtime`
- `SECRET_KEY_BASE: ${JWT_SECRET}`
- `DB_SSL: disable` (for local Docker)

#### 4. **PostgreSQL Connection Issues**
**Problem:** Services unable to connect to PostgreSQL in Docker network.
**Solution:** Add `?sslmode=disable` to all PostgreSQL connection URLs for local Docker setup.

#### 5. **Kong Gateway Template Issues**
**Problem:** Kong fails to start due to runtime envsubst installation failures on Debian ARM64 image.
**Solution:** Pre-render Kong configuration on host using envsubst before container startup.

### Debugging Strategies

#### Service Restart Loops
1. Check logs: `docker compose logs [service] --tail=50`
2. Verify database connectivity: `docker exec supabase-db pg_isready`
3. Check environment variables: `docker exec [service] env | grep KEY_VARS`
4. Examine database schema: Look for missing tables/types in auth/realtime schemas

#### Performance Issues on Pi 5
- Use ulimits optimized for Pi 5: 65536 instead of 262144
- Enable cgroupdriver=systemd in Docker daemon.json
- Monitor temperature: `vcgencmd measure_temp`
- Page size must be 4KB: `getconf PAGESIZE` (add `kernel=kernel8.img` to config.txt)

### Research-Based Solutions

All solutions implemented are based on extensive research from:
- Official Supabase documentation and GitHub issues
- Community solutions from Stack Overflow, Reddit r/selfhosted
- ARM64/Pi 5 specific compatibility reports
- Ecto/Elixir documentation for migration requirements

### Automatic Fix Integration

The setup scripts now include automatic detection and resolution of these issues:
- `fix_common_service_issues()` function in Week 2 script
- Pre-creation of required database schemas and types
- Complete environment variable configuration
- Proper error handling and retry mechanisms

## File Organization
- `setup-weekX.sh`: Main installation scripts for each week
- `WEEKX.md`: Detailed documentation and step-by-step guides
- `docs/`: Comprehensive usage guides and troubleshooting
  - `SUPABASE-USAGE-GUIDE.md`: Complete Supabase operation manual
  - `DOCKER-MANAGEMENT-GUIDE.md`: Docker administration reference
  - `ADDITIONAL-INSTALLATIONS.md`: Optional tools and optimizations
  - `PI5-SUPABASE-ISSUES-COMPLETE.md`: Detailed issue analysis
- `README.md`: Project overview and quick start guide
- `CLAUDE.md`: This development guidance file