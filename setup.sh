#!/usr/bin/env bash
# Bash 3.2+; Linux, macOS, Windows Git Bash, and WSL.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CPW_INSTALL_PREFIX="${CPW_PREFIX:-$HOME/.local/share/cpw}"
CPW_DRY_RUN=0
CPW_MINIMAL=0
CPW_NO_NVIM=0
for ((i=1; i<=$#; i++)); do
    arg="${!i}"
    case "$arg" in
        --prefix)
            j=$((i+1))
            if [ "$j" -gt "$#" ] || [ -z "${!j}" ]; then
                echo 'ERROR: --prefix requires a directory.' >&2; exit 2
            fi
            CPW_INSTALL_PREFIX="${!j}"; i=$j ;;
        --prefix=*) CPW_INSTALL_PREFIX="${arg#*=}" ;;
        --dry-run) CPW_DRY_RUN=1 ;;
        --minimal) CPW_MINIMAL=1 ;;
        --no-nvim) CPW_NO_NVIM=1 ;;
        --skip-system|--no-shell|--skip-extensions) ;;
        --help|-h)
            cat <<'HELP'
Usage: bash setup.sh [options]

Default: C++ compiler, isolated Python + oj + Kattis, submitter,
         Go + cf-tool, Node + Chrome bridge, browser extension files.

  --prefix DIR       Install directory (default: ~/.local/share/cpw)
  --no-nvim          Skip Neovim installation and configuration deployment
  --minimal          Install core tools; omit cf-tool, Node and Chrome bridge
  --skip-system      Use existing compiler/native build libraries
  --skip-extensions  Skip browser extension files and native host registration
  --no-shell         Do not edit shell startup files
  --dry-run          Print the plan; no downloads or filesystem changes
  --help             Show this help

Windows: run in Git Bash or WSL, not cmd.exe/PowerShell.
Browser login, extension activation and macOS CLT dialogs require user action.
HELP
            exit 0 ;;
        *) printf 'ERROR: Unknown option: %s\n' "$arg" >&2; exit 2 ;;
    esac
done
if [ -z "$CPW_INSTALL_PREFIX" ]; then echo 'ERROR: Empty prefix.' >&2; exit 2; fi
case "$CPW_INSTALL_PREFIX" in
    /|"$HOME"|"$HOME/"|[A-Za-z]:/|[A-Za-z]:)
        echo 'ERROR: Choose a dedicated install directory.' >&2; exit 2 ;;
esac
case "$(uname -s)" in
    Linux*) CPW_HOST=linux ;;
    Darwin*) CPW_HOST=macos ;;
    MINGW*|MSYS*) CPW_HOST=windows ;;
    *) echo 'ERROR: Supported: Linux, macOS, Git Bash on Windows, WSL.' >&2; exit 1 ;;
esac
native_path() {
    if [ "$CPW_HOST" = windows ]; then cygpath -m "$1"; else printf '%s\n' "$1"; fi
}
if [ "$CPW_DRY_RUN" = 1 ]; then
    printf 'DRY RUN: platform=%s prefix=%s\n' "$CPW_HOST" "$CPW_INSTALL_PREFIX"
    printf '%s\n' \
        '1. Check/install native compiler and build dependencies (unless --skip-system).' \
        '2. Bootstrap isolated uv and Python 3.12.' \
        '3. Install oj, Kattis CLI and submitter from pinned sources.' \
        "4. Profile: $(if [ "$CPW_MINIMAL" = 1 ]; then echo 'minimal (omit cf-tool, Go, Node and bridge)'; else echo 'full (install cf-tool, Go, Node and bridge)'; fi)." \
        '5. Prepare extension folders (unless --skip-extensions).' \
        '6. Install cpw commands and activation file; update shell unless --no-shell.' \
        "7. Neovim deployment: $(if [ "$CPW_NO_NVIM" = 1 ]; then echo skipped; else echo 'portable runtime + config, backup previous config'; fi)." \
        '8. Print browser activation and account login instructions.'
    exit 0
fi
# Bootstrap uv without changing the user's global Python or PATH.
CPW_UV_VERSION=0.13.9
mkdir -p "$CPW_INSTALL_PREFIX/bootstrap"
if [ "$CPW_HOST" = windows ]; then
    CPW_UV="$CPW_INSTALL_PREFIX/bootstrap/uv.exe"
else
    CPW_UV="$CPW_INSTALL_PREFIX/bootstrap/uv"
fi
if [ ! -x "$CPW_UV" ]; then
    command -v curl >/dev/null || { echo 'ERROR: Install curl first.' >&2; exit 1; }
    if [ "$CPW_HOST" = windows ]; then
        curl --fail --location --retry 3 --proto '=https' --tlsv1.2 \
            "https://astral.sh/uv/$CPW_UV_VERSION/install.ps1" \
            -o "$CPW_INSTALL_PREFIX/bootstrap/uv-install.ps1"
        UV_UNMANAGED_INSTALL="$(native_path "$CPW_INSTALL_PREFIX/bootstrap")"
        export UV_UNMANAGED_INSTALL
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File \
            "$(native_path "$CPW_INSTALL_PREFIX/bootstrap/uv-install.ps1")"
    else
        curl --fail --location --retry 3 --proto '=https' --tlsv1.2 \
            "https://astral.sh/uv/$CPW_UV_VERSION/install.sh" \
            -o "$CPW_INSTALL_PREFIX/bootstrap/uv-install.sh"
        UV_UNMANAGED_INSTALL="$CPW_INSTALL_PREFIX/bootstrap" \
            sh "$CPW_INSTALL_PREFIX/bootstrap/uv-install.sh"
    fi
fi
CPW_PREFIX="$(native_path "$CPW_INSTALL_PREFIX")"
export CPW_PREFIX
UV_PYTHON_INSTALL_DIR="$(native_path "$CPW_INSTALL_PREFIX/python")"
export UV_PYTHON_INSTALL_DIR
UV_CACHE_DIR="$(native_path "$CPW_INSTALL_PREFIX/cache/uv")"
export UV_CACHE_DIR
exec "$CPW_UV" run --no-project --python 3.12 --with certifi \
    "$(native_path "$ROOT/scripts/install.py")" "$@"
