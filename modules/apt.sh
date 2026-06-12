#!/bin/bash

apt_execute() {
    local command="$1"
    local description="$2"

    print_command "${command}"
    echo " "

    local exit_code=0
    eval "${command}" || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        print_success "${description} completed successfully"
        return 0
    else
        print_error "${description} failed with exit code ${exit_code}"
        state_add_error "${description} (exit code: ${exit_code})"
        return "${exit_code}"
    fi
}

apt_validate() {
    if ! command -v sudo &>/dev/null; then
        print_error "sudo is not installed (required for apt tasks)"
        return 1
    fi

    if ! command -v apt &>/dev/null; then
        print_error "apt is not available (required for apt tasks)"
        return 1
    fi

    return 0
}

apt_run() {
    local run_update="${1:-true}"
    local run_upgrade="${2:-true}"
    local run_dist_upgrade="${3:-false}"
    local run_autoremove="${4:-true}"
    local run_autoclean="${5:-true}"

    print_header "SYSTEM UPDATE PROCESS"

    local apt_commands=()

    if [[ "$run_update" == "true" ]]; then
        apt_commands+=("sudo apt update -y:Update Package Lists")
    fi

    if [[ "$run_upgrade" == "true" ]]; then
        apt_commands+=("apt list --upgradable:List Upgradable Packages")
    fi

    if [[ "$run_upgrade" == "true" ]]; then
        apt_commands+=("sudo apt upgrade -y:Upgrade Installed Packages")
    fi

    if [[ "$run_dist_upgrade" == "true" ]]; then
        apt_commands+=("sudo apt dist-upgrade -y:Distribution Upgrade")
    fi

    if [[ "$run_autoremove" == "true" ]]; then
        apt_commands+=("sudo apt autoremove --purge -y:Remove Unnecessary Packages")
    fi

    if [[ "$run_autoclean" == "true" ]]; then
        apt_commands+=("sudo apt autoclean -y:Clean Repository Cache")
    fi

    if [[ ${#apt_commands[@]} -eq 0 ]]; then
        print_warning "No apt operations configured"
        return 0
    fi

    local total_commands=${#apt_commands[@]}
    local current_command=0
    local failed_commands=()

    for command_info in "${apt_commands[@]}"; do
        IFS=: read -r command description <<< "$command_info"

        ((current_command++))
        print_step "${current_command}" "${total_commands}" "${description}"

        if apt_execute "$command" "$description"; then
            :
        else
            failed_commands+=("$description")
        fi

        echo " "
        print_separator
        echo " "
    done

    local successful_count=$((total_commands - ${#failed_commands[@]}))

    echo "${BOLD}Total Commands:${RESET} ${total_commands}"
    echo "${BOLD}Successful:${RESET} ${successful_count}"
    echo "${BOLD}Failed:${RESET} ${#failed_commands[@]}"
    echo " "

    if [[ ${#failed_commands[@]} -eq 0 ]]; then
        print_success "All system operations completed successfully! 🎉"
        return 0
    else
        print_error "Some operations failed: ${failed_commands[*]}"
        return 1
    fi
}