#!/bin/bash

pipx_update_self() {
    if ! command -v pipx &>/dev/null; then
        print_error "pipx is not installed"
        return 1
    fi

    if dpkg -s pipx &>/dev/null 2>&1; then
        print_status "pipx is managed by apt, will be updated via 'sudo apt upgrade'"
        return 0
    fi

    if [[ "$(which pipx)" == "/usr/"* ]]; then
        print_status "pipx is installed system-wide, use 'sudo apt upgrade' to update it"
        return 0
    fi

    print_command "pip3 install --user --upgrade pipx"
    echo " "

    if pip3 install --user --upgrade pipx 2>/dev/null || python3 -m pip install --user --upgrade pipx 2>/dev/null; then
        print_success "pipx updated to latest version"
        return 0
    else
        print_error "pipx update failed"
        return 1
    fi
}



pipx_validate() {
    if ! command -v pipx &>/dev/null; then
        print_warning "pipx is not installed, skipping pipx module"
        return 1
    fi
    return 0
}

pipx_run() {
    local update_self="${1:-true}"
    local upgrade_packages="${2:-false}"

    print_header "UPDATING PIPX"

    if [[ "$update_self" == "true" ]]; then
        print_step "1" "1" "Updating pipx to latest version"

        if pipx_update_self; then
            print_success "pipx update completed successfully! 🎉"
            return 0
        else
            print_error "pipx self-update failed"
            return 1
        fi
    fi

    return 0
}