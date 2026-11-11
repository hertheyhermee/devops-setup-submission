#!/usr/bin/env bash

failures=0

check() {
  local label="$1"
  shift
  printf '\n--- %s ---\n' "$label"
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'FAIL: command not found: %s\n' "$1"
    failures=$((failures + 1))
  elif ! "$@"; then
    printf 'FAIL: %s check did not succeed\n' "$label"
    failures=$((failures + 1))
  fi
}

check_memory() {
  local bytes
  case "$(uname -s)" in
    Darwin) bytes=$(sysctl -n hw.memsize 2>/dev/null) ;;
    Linux) bytes=$(awk '/MemTotal/ { print $2 * 1024; exit }' /proc/meminfo) ;;
    *)
      printf 'FAIL: RAM check supports macOS and Linux only\n'
      failures=$((failures + 1))
      return
      ;;
  esac

  if [[ "$bytes" =~ ^[0-9]+$ ]]; then
    printf 'Installed RAM: %.1f GiB\n' "$(awk -v bytes="$bytes" 'BEGIN { print bytes / 1073741824 }')"
    if (( bytes < 4294967296 )); then
      printf 'FAIL: at least 4 GiB RAM is required\n'
      failures=$((failures + 1))
    fi
  else
    printf 'FAIL: could not determine installed RAM\n'
    failures=$((failures + 1))
  fi
}

check_disk() {
  local available_kb
  available_kb=$(df -Pk "$HOME" | awk 'END { print $4 }')
  if [[ "$available_kb" =~ ^[0-9]+$ ]]; then
    printf 'Available space on home volume: %.1f GiB\n' \
      "$(awk -v kb="$available_kb" 'BEGIN { print kb / 1048576 }')"
    if (( available_kb < 10485760 )); then
      printf 'FAIL: at least 10 GiB free disk space is required\n'
      failures=$((failures + 1))
    fi
  else
    printf 'FAIL: could not determine available disk space\n'
    failures=$((failures + 1))
  fi
}

printf '=== Tooling Verification Report ===\n'
printf 'Generated: %s\n' "$(date)"
printf 'OS: %s\n' "$(uname -a)"

printf '\n--- Host requirements ---\n'
check_memory
check_disk

check "Homebrew" brew --version
check "Git" git --version
check "Visual Studio Code" code --version
check "Docker" docker --version
check "Docker Compose" docker compose version
check "kubectl" kubectl version --client
check "Minikube" minikube version
check "Helm" helm version --short
check "AWS CLI" aws --version
check "Azure CLI" az version
check "Node.js" node --version
check "npm" npm --version
check "jq" jq --version
check "Terraform" terraform --version
check "Ansible" ansible --version
check "Minikube cluster" minikube status
check "Kubernetes nodes" kubectl get nodes

printf '\n--- File permissions ---\n'
if [[ -x "${BASH_SOURCE[0]}" ]]; then
  printf 'PASS: verification script is executable\n'
else
  printf 'FAIL: verification script is not executable (run chmod +x %s)\n' "${BASH_SOURCE[0]}"
  failures=$((failures + 1))
fi

if (( failures == 0 )); then
  printf '\nRESULT: PASS (all checks succeeded)\n'
else
  printf '\nRESULT: FAIL (%d check(s) failed)\n' "$failures"
fi

exit "$failures"
