#!/bin/bash

kernel_validate() {
    if ! command -v purge-old-kernels &>/dev/null; then
        print_status "purge-old-kernels not found — will install via byobu"
        return 0
    fi
    return 0
}

kernel_cleanup() {
    local keep_count="$1"

    print_command "sudo purge-old-kernels --keep ${keep_count}"
    echo " "

    # purge-old-kernels exits non-zero when there's nothing to remove
    if sudo purge-old-kernels --keep "${keep_count}" 2>/dev/null; then
        print_success "Old kernel cleanup completed"
        return 0
    else
        print_success "No old kernels to remove"
        return 0
    fi
}

kernel_run() {
    local keep_count="${1:-2}"

    print_header "CLEANING OLD KERNELS"

    if ! command -v purge-old-kernels &>/dev/null; then
        print_step "0" "1" "Installing purge-old-kernels (byobu)"
        sudo apt install -y byobu 2>/dev/null || {
            print_error "Failed to install byobu"
            return 1
        }
        echo " "
    fi

    local installed_kernels
    installed_kernels=$(dpkg --list 2>/dev/null | grep -c '^ii.*linux-image-.*[0-9]\.')

    if [[ "$installed_kernels" -le "$keep_count" ]]; then
        print_step "1" "1" "Only ${installed_kernels} kernel(s) installed (keeping ${keep_count}) — nothing to clean"
        print_success "Kernel cleanup: nothing to do"
        return 0
    fi

    print_step "1" "1" "Removing old kernels (keeping newest ${keep_count})"
    kernel_cleanup "$keep_count"

    print_status "Cleaning up residual kernel packages..."
    sudo apt autoremove --purge -y 2>/dev/null
    echo " "

    return 0
}
