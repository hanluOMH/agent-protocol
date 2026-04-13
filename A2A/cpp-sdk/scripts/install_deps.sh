#!/usr/bin/env bash

# Install dependencies for a2a_cpp project.
#
# Supported platforms:
#   - macOS (Homebrew)
#   - Debian/Ubuntu
#   - RHEL/CentOS/Fedora/EulerOS
#   - Arch/Manjaro

set -euo pipefail

echo "==> Checking system dependencies for a2a_cpp..."

OS=""
if [[ "$(uname -s)" == "Darwin" ]]; then
    OS="macos"
elif [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS="${ID}"
else
    echo "Error: Cannot detect OS type"
    exit 1
fi

if [[ "${EUID}" -ne 0 ]]; then
    SUDO="sudo"
else
    SUDO=""
fi

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

check_deb_package() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

check_yum_package() {
    yum list installed "$1" >/dev/null 2>&1
}

check_brew_formula() {
    brew list --versions "$1" >/dev/null 2>&1
}

install_dependencies() {
    local need_curl=0
    local need_openssl=0
    local need_json=0
    local need_httplib=0

    case "${OS}" in
        macos)
            if check_brew_formula curl && command_exists curl-config; then
                echo "  - curl: OK"
            else
                echo "  - curl: NOT FOUND"
                need_curl=1
            fi

            if check_brew_formula openssl@3 && command_exists openssl; then
                echo "  - openssl@3: OK"
            else
                echo "  - openssl@3: NOT FOUND"
                need_openssl=1
            fi

            if check_brew_formula nlohmann-json; then
                echo "  - nlohmann-json: OK"
            else
                echo "  - nlohmann-json: NOT FOUND"
                need_json=1
            fi

            if check_brew_formula cpp-httplib || [[ -f /opt/homebrew/include/httplib.h ]] || [[ -f /usr/local/include/httplib.h ]]; then
                echo "  - cpp-httplib: OK"
            else
                echo "  - cpp-httplib: NOT FOUND"
                need_httplib=1
            fi
            ;;

        ubuntu|debian)
            if check_deb_package libcurl4 || check_deb_package libcurl3; then
                echo "  - libcurl: OK"
            else
                echo "  - libcurl: NOT FOUND"
                need_curl=1
            fi

            if check_deb_package libcurl4-openssl-dev; then
                echo "  - libcurl dev headers: OK"
            else
                echo "  - libcurl dev headers: NOT FOUND"
                need_curl=1
            fi

            if check_deb_package libssl-dev; then
                echo "  - openssl dev headers: OK"
            else
                echo "  - openssl dev headers: NOT FOUND"
                need_openssl=1
            fi
            ;;

        centos|rhel|fedora|euleros)
            if check_yum_package libcurl; then
                echo "  - libcurl: OK"
            else
                echo "  - libcurl: NOT FOUND"
                need_curl=1
            fi

            if check_yum_package libcurl-devel; then
                echo "  - libcurl-devel: OK"
            else
                echo "  - libcurl-devel: NOT FOUND"
                need_curl=1
            fi

            if check_yum_package openssl-devel; then
                echo "  - openssl-devel: OK"
            else
                echo "  - openssl-devel: NOT FOUND"
                need_openssl=1
            fi
            ;;

        arch|manjaro)
            if pacman -Q curl >/dev/null 2>&1; then
                echo "  - curl: OK"
            else
                echo "  - curl: NOT FOUND"
                need_curl=1
            fi

            if pacman -Q openssl >/dev/null 2>&1; then
                echo "  - openssl: OK"
            else
                echo "  - openssl: NOT FOUND"
                need_openssl=1
            fi
            ;;

        *)
            if command_exists curl-config; then
                echo "  - curl: OK"
            else
                echo "  - curl: NOT FOUND"
                need_curl=1
            fi

            if command_exists openssl; then
                echo "  - openssl: OK"
            else
                echo "  - openssl: NOT FOUND"
                need_openssl=1
            fi
            ;;
    esac

    if [[ ${need_curl} -eq 0 && ${need_openssl} -eq 0 && ${need_json} -eq 0 && ${need_httplib} -eq 0 ]]; then
        echo "==> All dependencies are already installed!"
        return 0
    fi

    echo ""
    echo "==> Installing missing dependencies..."

    case "${OS}" in
        macos)
            if ! command_exists brew; then
                echo "Error: Homebrew is required on macOS"
                exit 1
            fi

            local formulas=()
            [[ ${need_curl} -eq 1 ]] && formulas+=("curl")
            [[ ${need_openssl} -eq 1 ]] && formulas+=("openssl@3")
            [[ ${need_json} -eq 1 ]] && formulas+=("nlohmann-json")
            [[ ${need_httplib} -eq 1 ]] && formulas+=("cpp-httplib")

            if [[ ${#formulas[@]} -gt 0 ]]; then
                brew install "${formulas[@]}"
            fi
            ;;

        ubuntu|debian)
            $SUDO apt-get update -qq
            if [[ ${need_curl} -eq 1 ]]; then
                $SUDO apt-get install -y libcurl4-openssl-dev
            fi
            if [[ ${need_openssl} -eq 1 ]]; then
                $SUDO apt-get install -y libssl-dev
            fi
            ;;

        centos|rhel|fedora|euleros)
            if [[ ${need_curl} -eq 1 ]]; then
                $SUDO yum install -y libcurl libcurl-devel
            fi
            if [[ ${need_openssl} -eq 1 ]]; then
                $SUDO yum install -y openssl-libs openssl-devel
            fi
            ;;

        arch|manjaro)
            if [[ ${need_curl} -eq 1 || ${need_openssl} -eq 1 ]]; then
                $SUDO pacman -S --noconfirm curl openssl
            fi
            ;;

        *)
            echo "Error: Unsupported OS: ${OS}"
            echo "Please install curl, OpenSSL, nlohmann-json, and cpp-httplib manually."
            exit 1
            ;;
    esac

    echo ""
    echo "==> Dependency installation complete!"
}

check_dependencies() {
    echo ""
    echo "==> Verifying installation..."

    if command_exists curl-config && command_exists openssl; then
        echo "✓ Core dependencies verified successfully!"
        return 0
    fi

    echo "✗ Some dependencies are still missing. Please check the errors above."
    exit 1
}
