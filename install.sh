#!/usr/bin/env bash
# =============================================================================
# Easy Evil - Evilginx2 Installation Script
# by c0nfig17 | https://c0nfig17.com/
# =============================================================================

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
ok()   { echo -e "${GREEN}[+]${RESET} $*"; }
info() { echo -e "${CYAN}[*]${RESET} $*"; }
warn() { echo -e "${YELLOW}[!]${RESET} $*"; }
fail() { echo -e "${RED}[-]${RESET} $*"; exit 1; }

require_root() {
    if [[ $EUID -ne 0 ]]; then
        fail "Run this script as root or with sudo."
    fi
}

banner() {
    echo -e "${BOLD}${CYAN}"
    cat <<'EOF'
  ███████╗ █████╗ ███████╗██╗   ██╗    ███████╗██╗   ██╗██╗██╗
  ██╔════╝██╔══██╗██╔════╝╚██╗ ██╔╝    ██╔════╝██║   ██║██║██║
  █████╗  ███████║███████╗ ╚████╔╝     █████╗  ╚██╗ ██╔╝██║██║
  ██╔══╝  ██╔══██║╚════██║  ╚██╔╝      ██╔══╝   ╚████╔╝ ██║██║
  ███████╗██║  ██║███████║   ██║       ███████╗  ╚██╔╝  ██║███████╗
  ╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝       ╚══════╝   ╚═╝   ╚═╝╚══════╝
EOF
    echo -e "          Installer v1.0  —  by c0nfig17  |  https://c0nfig17.com/${RESET}"
    echo
}

# =============================================================================
# CHECKLIST
# =============================================================================
run_checklist() {
    echo -e "\n${BOLD}━━━ Pre-flight Checklist ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    local errors=0

    # 1. RAM >= 1 GB available
    local ram_available_kb
    ram_available_kb=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    if [[ $ram_available_kb -ge 1048576 ]]; then
        ok "RAM OK ($(( ram_available_kb / 1024 )) MB available)"
    else
        warn "Less than 1 GB RAM available ($(( ram_available_kb / 1024 )) MB)"
        (( errors++ )) || true
    fi

    # 2. Disk space >= 3 GB free on /
    local available_kb
    available_kb=$(df --output=avail / | tail -1)
    if [[ $available_kb -ge 3145728 ]]; then
        ok "Disk space OK ($(( available_kb / 1024 )) MB free on /)"
    else
        warn "Less than 3 GB free disk space ($(( available_kb / 1024 )) MB on /)"
        (( errors++ )) || true
    fi

    # 3. Ports 22 and 443 — warn only, never touch
    for port in 22 443; do
        if ss -tlnp 2>/dev/null | grep -q ":${port} " || \
           ss -ulnp 2>/dev/null | grep -q ":${port} "; then
            warn "Port ${port} is already in use"
            (( errors++ )) || true
        else
            ok "Port ${port} is free"
        fi
    done

    # 4. Port 53 — auto-fix via systemd-resolved if occupied
    _check_port53() {
        ss -tlnp 2>/dev/null | grep -q ":53 " || \
        ss -ulnp 2>/dev/null | grep -q ":53 "
    }

    if _check_port53; then
        info "Port 53 is in use. Identifying process…"
        lsof -i :53 2>/dev/null || true
        netstat -tulnp 2>/dev/null | grep ":53" || true

        if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
            info "Stopping and disabling systemd-resolved…"
            systemctl stop systemd-resolved
            systemctl disable systemd-resolved
            sleep 1
            if _check_port53; then
                warn "Port 53 still in use after stopping systemd-resolved"
                (( errors++ )) || true
            else
                ok "Port 53 freed (systemd-resolved stopped and disabled)"
            fi
        else
            warn "Port 53 is in use by a non-systemd-resolved process — free it manually"
            (( errors++ )) || true
        fi
    else
        ok "Port 53 is free"
    fi

    # 5. Non-root sudoer with authorized_keys
    local sudoer_ok=false
    while IFS=: read -r username _ uid _ _ homedir _; do
        [[ $uid -lt 1000 || $username == "root" ]] && continue
        if id -nG "$username" 2>/dev/null | grep -qw "sudo\|wheel"; then
            local auth_keys="${homedir}/.ssh/authorized_keys"
            if [[ -s "$auth_keys" ]]; then
                ok "User '${username}' is a sudoer with authorized_keys configured"
                sudoer_ok=true
                break
            else
                warn "User '${username}' is a sudoer but has no authorized_keys at ${auth_keys}"
            fi
        fi
    done < /etc/passwd

    if ! $sudoer_ok; then
        warn "No non-root sudoer with pre-configured SSH authorized_keys found"
        (( errors++ )) || true
    fi

    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    if [[ $errors -gt 0 ]]; then
        warn "${errors} checklist warning(s). Review before proceeding."
        echo
        read -rp "$(echo -e "${YELLOW}[?]${RESET} Continue anyway? [y/N] ")" answer
        [[ "${answer,,}" == "y" ]] || fail "Aborted by user."
    else
        ok "All checklist items passed."
    fi
}

# =============================================================================
# STEP 1 — System packages
# =============================================================================
install_packages() {
    echo -e "\n${BOLD}━━━ Step 1/4 — System Packages ━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    info "Updating package lists…"
    apt-get update -qq
    ok "Package lists updated"

    local pkgs=(git curl make tmux)
    for pkg in "${pkgs[@]}"; do
        if dpkg -s "$pkg" &>/dev/null; then
            ok "${pkg} already installed — skipping"
        else
            info "Installing ${pkg}…"
            apt-get install -y -qq "$pkg"
            ok "${pkg} installed"
        fi
    done
}

# =============================================================================
# STEP 2 — Go
# =============================================================================
GO_VERSION="1.22.3"
GO_TARBALL="go${GO_VERSION}.linux-amd64.tar.gz"
GO_URL="https://go.dev/dl/${GO_TARBALL}"
GO_INSTALL_DIR="/usr/local"
GO_BIN="${GO_INSTALL_DIR}/go/bin/go"

install_go() {
    echo -e "\n${BOLD}━━━ Step 2/4 — Go ${GO_VERSION} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    if [[ -x "$GO_BIN" ]]; then
        local current
        current=$("$GO_BIN" version 2>/dev/null | awk '{print $3}' | sed 's/go//')
        if [[ "$current" == "$GO_VERSION" ]]; then
            ok "Go ${GO_VERSION} already installed — skipping"
            _ensure_go_path
            return
        fi
        info "Replacing existing Go ${current} with ${GO_VERSION}…"
    fi

    info "Removing old Go installation…"
    rm -rf "${GO_INSTALL_DIR}/go"
    ok "Old Go removed"

    local tmp_tar="/tmp/${GO_TARBALL}"
    info "Downloading Go ${GO_VERSION}…"
    curl -fsSL -o "$tmp_tar" "$GO_URL"
    ok "Download complete"

    info "Extracting Go to ${GO_INSTALL_DIR}…"
    tar -C "$GO_INSTALL_DIR" -xzf "$tmp_tar"
    rm -f "$tmp_tar"
    ok "Go ${GO_VERSION} extracted"

    _ensure_go_path
    ok "Go installed: $("$GO_BIN" version)"
}

_ensure_go_path() {
    local export_line='export PATH=$PATH:/usr/local/go/bin'

    local profile_d="/etc/profile.d/golang.sh"
    if [[ ! -f "$profile_d" ]] || ! grep -qF "$export_line" "$profile_d"; then
        echo "$export_line" >> "$profile_d"
        ok "Go PATH added to ${profile_d}"
    fi

    local target_rc
    if [[ -n "${SUDO_USER:-}" ]]; then
        target_rc=$(getent passwd "$SUDO_USER" | cut -d: -f6)/.bashrc
    else
        target_rc="$HOME/.bashrc"
    fi

    if [[ -f "$target_rc" ]] && ! grep -qF "$export_line" "$target_rc"; then
        echo "$export_line" >> "$target_rc"
        ok "Go PATH added to ${target_rc}"
    fi

    export PATH=$PATH:/usr/local/go/bin
}

# =============================================================================
# STEP 3 — Node.js (via nvm, installed for the target user)
# =============================================================================
NODE_VERSION="18"
NVM_VERSION="v0.39.7"
NVM_URL="https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh"

install_node() {
    echo -e "\n${BOLD}━━━ Step 3/4 — Node.js ${NODE_VERSION} (nvm) ━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    local target_user target_home
    if [[ -n "${SUDO_USER:-}" ]]; then
        target_user="$SUDO_USER"
        target_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        target_user="$USER"
        target_home="$HOME"
    fi

    local nvm_dir="${target_home}/.nvm"

    if [[ -s "${nvm_dir}/nvm.sh" ]]; then
        ok "nvm already installed at ${nvm_dir} — skipping download"
    else
        info "Installing nvm ${NVM_VERSION} for user '${target_user}'…"
        if [[ "$target_user" != "root" && -n "${SUDO_USER:-}" ]]; then
            sudo -u "$target_user" bash -c \
                "curl -fsSL '${NVM_URL}' | NVM_DIR='${nvm_dir}' bash" 2>/dev/null
        else
            curl -fsSL "$NVM_URL" | NVM_DIR="$nvm_dir" bash 2>/dev/null
        fi
        ok "nvm installed"
    fi

    _nvm_run() {
        local cmd="source '${nvm_dir}/nvm.sh' && $*"
        if [[ "$target_user" != "root" && -n "${SUDO_USER:-}" ]]; then
            sudo -u "$target_user" bash -c "$cmd"
        else
            bash -c "$cmd"
        fi
    }

    info "Installing Node.js ${NODE_VERSION}…"
    _nvm_run "nvm install ${NODE_VERSION}"
    _nvm_run "nvm use ${NODE_VERSION}"
    _nvm_run "nvm alias default ${NODE_VERSION}"
    ok "Node.js $(_nvm_run "node -v" 2>/dev/null) installed"
    ok "npm $(_nvm_run "npm -v" 2>/dev/null) installed"
}

# =============================================================================
# STEP 4 — Evilginx2  (cloned to /evilginx at filesystem root)
# =============================================================================
EVILGINX_REPO="https://github.com/kgretzky/evilginx2.git"
EVILGINX_DIR="/evilginx"

install_evilginx() {
    echo -e "\n${BOLD}━━━ Step 4/4 — Evilginx2 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    info "Install location: ${EVILGINX_DIR}  (filesystem root)"

    if [[ -d "${EVILGINX_DIR}/.git" ]]; then
        info "Repository already exists at ${EVILGINX_DIR} — pulling latest…"
        git -C "$EVILGINX_DIR" pull -q
        ok "Repository updated"
    else
        info "Cloning evilginx2 into ${EVILGINX_DIR}…"
        git clone -q "$EVILGINX_REPO" "$EVILGINX_DIR"
        ok "Repository cloned to ${EVILGINX_DIR}"
    fi

    info "Building evilginx2 (make)…"
    set +o pipefail
    make -C "$EVILGINX_DIR" 2>&1 | while IFS= read -r line; do
        echo -e "    ${CYAN}│${RESET} ${line}"
    done
    local make_status=${PIPESTATUS[0]}
    set -o pipefail
    if [[ $make_status -ne 0 ]]; then
        fail "make failed with exit code ${make_status}"
    fi
    ok "Evilginx2 built successfully"

    local binary="${EVILGINX_DIR}/build/evilginx"
    if [[ ! -f "$binary" ]]; then
        # Fallback: search up to 3 levels
        binary=$(find "$EVILGINX_DIR" -maxdepth 3 -name "evilginx" -type f | head -1)
    fi

    if [[ -n "$binary" && -f "$binary" ]]; then
        chmod 700 "$binary"
        ok "Binary ready at ${binary} (chmod 700)"
    else
        warn "Binary not found — check build output above"
    fi
}

# =============================================================================
# SUMMARY
# =============================================================================
print_summary() {
    echo
    echo -e "${BOLD}${GREEN}━━━ Installation Complete ━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${GREEN}[+]${RESET} Go      : $(/usr/local/go/bin/go version 2>/dev/null || echo 'check manually')"
    echo -e "  ${GREEN}[+]${RESET} Evilginx: ${EVILGINX_DIR}/build/evilginx"
    echo
    echo -e "  ${CYAN}[*]${RESET} To start evilginx:"
    echo -e "       ${BOLD}tmux a -t evilginx${RESET}          (reconnect to existing session)"
    echo -e "       ${BOLD}cd /evilginx/build${RESET}"
    echo -e "       ${BOLD}sudo ./evilginx -p ../phishlets/${RESET}"
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    banner
    require_root
    run_checklist
    install_packages
    install_go
    install_node
    install_evilginx
    print_summary
}

main "$@"
