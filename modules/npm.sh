#!/bin/bash

npm_configure_prefix() {
    local npm_prefix="$HOME/.local"

    if ! command -v npm &>/dev/null; then
        print_error "npm is not installed"
        return 1
    fi

    if [[ -f "$HOME/.npmrc" ]] && grep -qxF "prefix=${npm_prefix}" "$HOME/.npmrc" 2>/dev/null; then
        return 0
    fi

    local current_prefix
    current_prefix=$(npm config get prefix 2>/dev/null)

    if [[ "$current_prefix" == "$npm_prefix" ]]; then
        return 0
    fi

    print_status "Configuring npm to use user-level prefix: ${npm_prefix}"

    if ! mkdir -p "$npm_prefix"; then
        print_error "Failed to create npm prefix directory: ${npm_prefix}"
        return 1
    fi

    if ! npm config set prefix "$npm_prefix" 2>/dev/null; then
        echo "prefix=${npm_prefix}" >> "$HOME/.npmrc"
        if grep -qxF "prefix=${npm_prefix}" "$HOME/.npmrc" 2>/dev/null; then
            print_status "npm prefix set in .npmrc (direct write)"
        else
            print_error "Failed to configure npm prefix in .npmrc"
            return 1
        fi
    fi

    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
        if [[ -f "$HOME/.bashrc" ]]; then
            cp "$HOME/.bashrc" "$HOME/.bashrc.backup.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
        fi
        {
            echo ''
            echo '# Added by Maintenance.sh - npm local prefix'
            echo 'export PATH="$HOME/.local/bin:$PATH"'
        } >> "$HOME/.bashrc" 2>/dev/null || true
        print_status "Added npm local bin to PATH in .bashrc"
    fi

    export PATH="$npm_prefix/bin:$PATH"
    return 0
}



npm_update_self() {
    if ! npm_configure_prefix; then
        print_error "Cannot update npm because npm prefix setup failed"
        return 1
    fi

    print_command "npm install --global npm@latest"
    echo " "

    if npm install --global npm@latest 2>/dev/null; then
        local npm_version
        npm_version=$(npm --version 2>/dev/null || echo 'unknown')
        print_success "npm updated to latest version (${npm_version})"
        return 0
    else
        print_error "npm update failed"
        return 1
    fi
}

npm_validate() {
    if ! command -v npm &>/dev/null; then
        print_warning "npm is not installed, skipping npm module"
        return 1
    fi
    return 0
}

npm_run() {
    local update_self="${1:-true}"

    print_header "UPDATING NPM"

    if [[ "$update_self" == "true" ]]; then
        print_step "1" "1" "Updating npm to latest version"

        if npm_update_self; then
            print_success "npm update completed successfully! 🎉"
            return 0
        else
            print_error "npm self-update failed"
            return 1
        fi
    fi

    return 0
}