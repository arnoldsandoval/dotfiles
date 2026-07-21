# platform.sh — OS / distro / package-manager detection. Sourced after core.sh.
# shellcheck shell=bash

detect_platform() {
  case "$(uname -s)" in
    Darwin) OS=darwin; DISTRO=macos; PKG_MGR=brew ;;
    Linux)
      OS=linux
      DISTRO=other
      if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        DISTRO=$(. /etc/os-release && echo "${ID:-other}")
      fi
      case "$DISTRO" in
        ubuntu|debian) PKG_MGR=apt ;;
        mariner|azurelinux) PKG_MGR=tdnf ;;
        *) PKG_MGR=none ;;
      esac
      ;;
    *) OS=unknown; DISTRO=unknown; PKG_MGR=none ;;
  esac
  export OS DISTRO PKG_MGR
}

# Can we sudo without prompting? (bootstrap may still offer interactive sudo)
has_passive_sudo() { sudo -n true 2>/dev/null; }

has_github_auth() {
  has gh && gh auth status -h github.com >/dev/null 2>&1 && return 0
  [[ -n ${HOMEBREW_GITHUB_API_TOKEN:-} ]]
}

detect_platform
