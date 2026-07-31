#!/bin/bash

<<COMMENT
=====================================================================
                    MAINTENANCE AUTOMATION SCRIPT
=====================================================================
Description:
  - Automated maintenance script for updating system packages and package managers
  - Updates system packages (apt), Node.js (latest LTS), npm, and pipx
  - Refreshes rkhunter database after updates

Features:
  - Modular design with separate modules
  - Color-coded output
  - Error handling and state tracking
  - Execution time tracking
  - Log files for debugging

Usage: ./Maintenance.sh [options]
  Options:
    help      - Show this help
    -h        - Show this help
=====================================================================
COMMENT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
MODULE_DIR="${SCRIPT_DIR}/modules"

for lib_file in "${LIB_DIR}"/*.sh; do
    source "$lib_file"
done

set +e

refresh_rkhunter_database() {
    # Only run if rkhunter is installed
    if ! command -v rkhunter &>/dev/null; then
        print_status "rkhunter not installed — skipping database refresh"
        return 0
    fi

    print_header "RHUNTER DATABASE REFRESH"
    print_step "1" "1" "Updating rkhunter file property database"
    print_command "sudo rkhunter --propupd"
    echo " "

    local exit_code=0
    sudo rkhunter --propupd 2>&1 || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        print_success "rkhunter database updated successfully"
        return 0
    else
        print_error "rkhunter database update failed with exit code ${exit_code}"
        state_add_finding "WARNING" "rkhunter --propupd failed" "Run manually: sudo rkhunter --propupd"
        return "${exit_code}"
    fi
}

run_all_modules() {
    local start_time end_time execution_time
    start_time=$(get_timestamp)

    module_run "apt" "true" "true" "false" "true" "true"
    module_run "kernel" "2"
    module_run "node"
    module_run "npm" "true"
    module_run "pipx" "true" "false"
    
    # Refresh rkhunter database after system updates
    refresh_rkhunter_database

    end_time=$(get_timestamp)
    execution_time=$((end_time - start_time))

    if state_has_errors; then
        local log_file
        log_file=$(get_log_file)
        state_log_to_file "$log_file"
    fi

    print_final_summary "${execution_time}" "6"
}

main() {
    init_colors
    run_all_modules
}

if [[ "${1:-}" == "help" || "${1:-}" == "-h" ]]; then
    init_colors
    echo " "
    echo "Usage: ./Maintenance.sh"
    echo " "
    echo "This script runs all maintenance tasks automatically:"
    echo "  1. Apt System Update (update + list upgradable -a + upgrade + cleanup)"
    echo "  2. Clean up old kernels (keeps newest 2)"
    echo "  3. Update Node.js to latest stable LTS (NodeSource)"
    echo "  4. Update npm to latest compatible version"
    echo "  5. Update pipx to latest"
    echo "  6. Refresh rkhunter database (after updates)"
    echo " "
    exit 0
fi

main "$@"
