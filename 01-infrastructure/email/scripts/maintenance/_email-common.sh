#!/usr/bin/env bash
#==============================================================================
# PI5-EMAIL-STACK - COMMON CONFIGURATION FOR MAINTENANCE SCRIPTS
#==============================================================================
# This file is sourced by wrapper scripts to provide common variables
# and paths for the email stack maintenance operations.
#==============================================================================

# Email Stack Directories
export EMAIL_STACK_DIR="/opt/pi5-email"
export EMAIL_CONFIG_DIR="${EMAIL_STACK_DIR}/config"
export EMAIL_COMPOSE_FILE="${EMAIL_STACK_DIR}/compose/docker-compose.yml"
export EMAIL_ENV_FILE="${EMAIL_STACK_DIR}/.env"
export EMAIL_LOG_DIR="/var/log/pi5-email"
export EMAIL_BACKUP_DIR="/var/backups/pi5-email"

# Container Names
export ROUNDCUBE_CONTAINER="roundcube"
export ROUNDCUBE_DB_CONTAINER="roundcube-db"
export MAIL_DB_CONTAINER="mail-db"
export POSTFIX_CONTAINER="postfix"
export DOVECOT_CONTAINER="dovecot"
export RSPAMD_CONTAINER="rspamd"

# Service Name (for common-scripts)
export SERVICE_NAME="email"
export COMPOSE_PROJECT="pi5-email"

# Common Scripts Directory
export COMMON_SCRIPTS_DIR="/opt/pi5-setup/common-scripts"

# Backup Configuration
export BACKUP_RETENTION_DAILY=7
export BACKUP_RETENTION_WEEKLY=4
export BACKUP_RETENTION_MONTHLY=3

# Health Check Endpoints
export ROUNDCUBE_HEALTH_URL="http://localhost:8080/"
export RSPAMD_HEALTH_URL="http://localhost:11334/"
