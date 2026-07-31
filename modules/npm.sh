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

npm_get_semver_path() {
    local npm_bin npm_js_dir candidate root
    npm_bin=$(command -v npm 2>/dev/null) || return 1
    npm_js_dir=$(readlink -f "$npm_bin")

    if [[ "$npm_js_dir" == */bin/npm-cli.js ]]; then
        candidate="${npm_js_dir%/bin/npm-cli.js}/node_modules/semver"
        if [[ -f "$candidate/package.json" ]]; then
            echo "$candidate"
            return 0
        fi
    fi

    root=$(npm root -g 2>/dev/null)
    for candidate in "${root}/npm/node_modules/semver" "${root}/semver"; do
        if [[ -f "$candidate/package.json" ]]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

npm_get_highest_compatible() {
    local node_version semver_path
    node_version=$(node -v 2>/dev/null | sed 's/^v//')
    [[ -z "$node_version" ]] && return 1

    semver_path=$(npm_get_semver_path) || return 1

    local script
    script=$(mktemp)
    cat > "$script" <<'EOF'
const semver = require(process.argv[3]);
const nodeVersion = process.argv[2];
let data = '';
process.stdin.on('data', (c) => (data += c));
process.stdin.on('end', () => {
  try {
    const pkg = JSON.parse(data);
    const versions = Object.keys(pkg.versions || {})
      .filter((v) => {
        if (semver.prerelease(v)) return false;
        const engines = pkg.versions[v].engines;
        return engines && engines.node && semver.satisfies(nodeVersion, engines.node);
      })
      .sort((a, b) => semver.rcompare(a, b));
    if (versions.length > 0) {
      process.stdout.write(versions[0]);
      process.exit(0);
    }
  } catch (_) {}
  process.exit(1);
});
EOF

    local result
    result=$(curl -fsSL --connect-timeout 10 --max-time 60 \
        -H 'Accept: application/vnd.npm.install-v1+json' \
        https://registry.npmjs.org/npm 2>/dev/null | node "$script" "$node_version" "$semver_path")
    local exit_code=$?
    rm -f "$script"

    if [[ $exit_code -ne 0 || -z "$result" ]]; then
        return 1
    fi
    echo "$result"
}

npm_update_self() {
    if ! npm_configure_prefix; then
        print_error "Cannot update npm because npm prefix setup failed"
        return 1
    fi

    local current_version compatible_version install_output
    current_version=$(npm --version 2>/dev/null || echo 'unknown')

    compatible_version=$(npm_get_highest_compatible)

    if [[ -z "$compatible_version" ]]; then
        print_warning "Could not determine the highest npm version compatible with Node.js $(node -v 2>/dev/null || echo 'unknown')"
        print_status "Falling back to npm@latest..."
        compatible_version="latest"
    fi

    print_command "npm install --global npm@${compatible_version}"
    echo " "

    install_output=$(npm install --global "npm@${compatible_version}" 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        local new_version
        new_version=$(npm --version 2>/dev/null || echo 'unknown')
        if [[ "$new_version" == "$current_version" ]]; then
            print_success "npm is already up to date (${new_version})"
        else
            print_success "npm updated from ${current_version} to ${new_version}"
        fi
        return 0
    else
        print_error "npm update failed with exit code ${exit_code}"
        print_error "Reason:"
        while IFS= read -r line; do
            [[ -n "$line" ]] && print_error "  ${line}"
        done <<< "$install_output"
        state_add_error "npm update failed: $(printf '%s\n' "$install_output" | head -1)"
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
        print_step "1" "1" "Updating npm to latest compatible version"

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
