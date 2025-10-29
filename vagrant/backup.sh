#!/usr/bin/env bash

################################################################################
# Database Backup Script
#
# This script creates a backup of the PostgreSQL database from the Swarm
# deployment and stores it in the vagrant/backups directory (synced folder).
#
# Usage:
#   ./vagrant/backup.sh
#
# The backup will be saved as: backup-YYYYMMDD-HHMMSS.sql
#
################################################################################

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BACKUP_DIR="$SCRIPT_DIR/backups"
readonly TIMESTAMP=$(date +%Y%m%d-%H%M%S)
readonly BACKUP_FILE="backup-${TIMESTAMP}.sql"
readonly MAX_BACKUPS=7  # Keep last 7 backups

# Color codes
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

################################################################################
# Functions
################################################################################

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

check_prerequisites() {
    # Check if in correct directory
    if [[ ! -f "$SCRIPT_DIR/Vagrantfile" ]]; then
        print_error "Must run from vagrant directory or vagrant/backup.sh"
        exit 1
    fi
    
    # Check if VM is running
    cd "$SCRIPT_DIR"
    if ! vagrant status 2>/dev/null | grep -q "running"; then
        print_error "Vagrant VM is not running"
        print_info "Start VM with: cd vagrant && vagrant up"
        exit 1
    fi
    
    # Check if database container is running
    if ! vagrant ssh -c "docker ps --filter 'name=names-app_db' --format '{{.Names}}'" 2>/dev/null | grep -q "names-app_db"; then
        print_error "Database container is not running"
        print_info "Deploy stack with: ./ops/deploy.sh"
        exit 1
    fi
    
    # Ensure backup directory exists
    mkdir -p "$BACKUP_DIR"
}

create_backup() {
    print_info "Creating backup: $BACKUP_FILE"
    
    # Execute pg_dump inside container and save to synced folder
    if vagrant ssh -c "docker exec \$(docker ps -q -f name=names-app_db) \
        pg_dump -U postgres names_db" > "$BACKUP_DIR/$BACKUP_FILE" 2>/dev/null; then
        
        local size=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
        print_success "Backup created: $BACKUP_FILE ($size)"
        return 0
    else
        print_error "Backup failed!"
        rm -f "$BACKUP_DIR/$BACKUP_FILE"  # Remove failed backup
        return 1
    fi
}

cleanup_old_backups() {
    print_info "Cleaning up old backups (keeping last $MAX_BACKUPS)..."
    
    local backup_count=$(ls -1 "$BACKUP_DIR"/backup-*.sql 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ $backup_count -gt $MAX_BACKUPS ]]; then
        local to_delete=$((backup_count - MAX_BACKUPS))
        ls -t "$BACKUP_DIR"/backup-*.sql | tail -n +$((MAX_BACKUPS + 1)) | while read -r old_backup; do
            rm -f "$old_backup"
            print_info "Deleted old backup: $(basename "$old_backup")"
        done
        print_success "Removed $to_delete old backup(s)"
    else
        print_info "No old backups to remove ($backup_count total)"
    fi
}

show_backup_list() {
    echo ""
    print_info "Available backups:"
    
    if ls "$BACKUP_DIR"/backup-*.sql >/dev/null 2>&1; then
        ls -lh "$BACKUP_DIR"/backup-*.sql | awk '{print "  " $9 " (" $5 ")"}'
    else
        print_info "  (no backups found)"
    fi
    
    echo ""
}

################################################################################
# Main
################################################################################

main() {
    echo ""
    echo "======================================"
    echo "Database Backup Script"
    echo "======================================"
    echo ""
    
    # Run checks
    check_prerequisites
    
    # Create backup
    if create_backup; then
        # Clean up old backups
        cleanup_old_backups
        
        # Show backup list
        show_backup_list
        
        echo "======================================"
        print_success "Backup completed successfully!"
        echo "======================================"
        echo ""
        print_info "Restore with:"
        echo "  cd vagrant"
        echo "  vagrant ssh -c \"docker exec -i \\\$(docker ps -q -f name=names-app_db) \\"
        echo "    psql -U postgres names_db < /vagrant/backups/$BACKUP_FILE\""
        echo ""
        
        exit 0
    else
        echo "======================================"
        print_error "Backup failed!"
        echo "======================================"
        exit 1
    fi
}

# Run main function
main "$@"
