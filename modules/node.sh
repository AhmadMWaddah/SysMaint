#!/bin/bash

node_get_latest_lts() {
    local data
    data=$(curl -fsSL --connect-timeout 10 --max-time 30 https://nodejs.org/dist/index.json 2>/dev/null) || return 1

    if command -v jq &>/dev/null; then
        jq -r '[.[] | select(.lts != false)][0].version // empty' <<< "$data" 2>/dev/null
        return 0
    fi

    if command -v python3 &>/dev/null; then
        python3 -c 'import sys,json; d=json.load(sys.stdin); print(next((x["version"] for x in d if x.get("lts")), ""))' <<< "$data" 2>/dev/null
        return 0
    fi

    return 1
}

node_install_lts() {
    local setup_script
    setup_script=$(mktemp)

    print_command "curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -"
    echo " "

    if ! curl -fsSL --connect-timeout 10 --max-time 60 -o "$setup_script" https://deb.nodesource.com/setup_lts.x; then
        print_error "Failed to download the NodeSource setup script (network issue?)"
        rm -f "$setup_script"
        return 1
    fi

    if ! sudo -E bash "$setup_script"; then
        print_error "NodeSource LTS repository setup failed"
        rm -f "$setup_script"
        return 1
    fi
    rm -f "$setup_script"

    print_status "Updating package lists..."
    echo " "
    if ! sudo apt update 2>&1; then
        print_error "apt update failed"
        return 1
    fi

    print_status "Installing Node.js LTS..."
    echo " "
    if ! sudo apt install -y nodejs 2>&1; then
        print_error "apt install nodejs failed"
        return 1
    fi

    local new_version
    new_version=$(node -v 2>/dev/null || echo 'unknown')
    print_success "Node.js updated to ${new_version}"
    return 0
}

node_update() {
    if ! command -v node &>/dev/null; then
        print_status "Node.js is not installed — installing latest LTS from NodeSource"
        node_install_lts
        return $?
    fi

    local current latest_lts current_major lts_major
    current=$(node -v 2>/dev/null || echo 'unknown')
    latest_lts=$(node_get_latest_lts)

    if [[ -z "$latest_lts" ]]; then
        print_warning "Could not fetch latest Node.js LTS version (network issue?) — skipping node update"
        return 0
    fi

    current_major="${current#v}"
    current_major="${current_major%%.*}"
    lts_major="${latest_lts#v}"
    lts_major="${lts_major%%.*}"

    if [[ "$current_major" == "$lts_major" ]]; then
        print_success "Node.js ${current} is already on the latest LTS major (${latest_lts})"
        return 0
    fi

    print_status "Node.js ${current} is behind the latest LTS (${latest_lts}) — upgrading"
    echo " "
    node_install_lts
    return $?
}

node_validate() {
    if ! command -v curl &>/dev/null; then
        print_warning "curl is not installed, skipping node module"
        return 1
    fi
    if ! command -v sudo &>/dev/null; then
        print_warning "sudo is not installed, skipping node module"
        return 1
    fi
    return 0
}

node_run() {
    print_header "UPDATING NODE.JS"

    local current_version
    current_version=$(node -v 2>/dev/null || echo 'not installed')
    print_status "Current Node.js version: ${current_version}"
    echo " "

    print_step "1" "1" "Updating Node.js to latest stable LTS"

    if node_update; then
        print_success "Node.js update completed successfully! 🎉"
        return 0
    else
        print_error "Node.js update failed"
        state_add_error "Node.js update failed"
        return 1
    fi
}
