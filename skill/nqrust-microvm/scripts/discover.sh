#!/usr/bin/env bash
# nqrust-microvm DISCOVERY — run on the TARGET host (over ssh) on first contact.
# Detects hardware specs + networking so the agent can RECOMMEND a configuration.
# Grounded in the system requirements at https://microvm.nexusquantum.id
#   (min: x86_64+KVM, 4GB RAM, 20GB disk, Ubuntu 22.04/24.04 or Debian 11;
#    recommended: 8GB+ RAM, 50GB+ disk, Ubuntu 24.04 LTS).
# Output: human lines, then a machine-readable `=== DISCOVERY ===` KEY=VALUE block.
set -uo pipefail
say() { printf '%s\n' "$*"; }

say "== nqrust-microvm discovery =="

# --- OS / arch / kernel ---
ARCH="$(uname -m)"; KERNEL="$(uname -r)"
OS_ID=""; OS_VER=""; OS_PRETTY=""
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release; OS_ID="${ID:-}"; OS_VER="${VERSION_ID:-}"; OS_PRETTY="${PRETTY_NAME:-}"
fi
OS_SUPPORTED="no"
case "${OS_ID}:${OS_VER}" in
  ubuntu:22.04|ubuntu:24.04|debian:11|debian:12) OS_SUPPORTED="yes" ;;
  *) printf '%s %s' "${ID:-}" "${ID_LIKE:-}" | grep -qiE 'ubuntu|debian' && OS_SUPPORTED="likely" ;;
esac

# --- CPU / virtualization ---
CPU_CORES="$(nproc 2>/dev/null || echo 1)"
CPU_MODEL="$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ *//')"
VIRT_FLAGS="$(grep -cE '(vmx|svm)' /proc/cpuinfo 2>/dev/null || echo 0)"
VIRT_TYPE="none"
grep -qm1 vmx /proc/cpuinfo 2>/dev/null && VIRT_TYPE="VT-x"
grep -qm1 svm /proc/cpuinfo 2>/dev/null && VIRT_TYPE="AMD-V"
KVM="missing"; [ -e /dev/kvm ] && KVM="present"

# --- RAM ---
RAM_GB="$(awk '/MemTotal/{printf "%.1f",$2/1024/1024}' /proc/meminfo 2>/dev/null || echo 0)"

# --- Disk (root holds /opt, /srv, /var by default) ---
DISK_TOTAL_GB="$(df -BG --output=size / 2>/dev/null | tail -1 | tr -dc 0-9)"
DISK_FREE_GB="$(df -BG --output=avail / 2>/dev/null | tail -1 | tr -dc 0-9)"
SRV_FREE_GB="$DISK_FREE_GB"
if mountpoint -q /srv 2>/dev/null; then
  SRV_FREE_GB="$(df -BG --output=avail /srv 2>/dev/null | tail -1 | tr -dc 0-9)"
fi

# --- Networking: default route, primary uplink, interfaces ---
GW="$(ip route 2>/dev/null | awk '/^default/{print $3; exit}')"
UPLINK="$(ip route 2>/dev/null | awk '/^default/{print $5; exit}')"
PRIMARY_IP="$(ip -o -4 addr show "${UPLINK:-lo}" 2>/dev/null | awk '{print $4}' | head -1)"
# physical-ish NICs (exclude loopback + virtual/overlay)
NIC_LIST="$(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' \
  | grep -vE '^(lo|docker|veth|virbr|fcbr|cni|flannel|tap|tun|kube|br-|wg)' | paste -sd, -)"
NIC_COUNT="$(printf '%s' "$NIC_LIST" | tr ',' '\n' | grep -c .)"
PRIV="no"
printf '%s' "$PRIMARY_IP" | grep -qE '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)' && PRIV="yes"
VIRTUALIZED="$(systemd-detect-virt 2>/dev/null || echo unknown)"

# --- Default install ports busy? (3000 UI, 18080 manager, 9090 agent, 5432 pg) ---
PORTS_BUSY=""
for p in 3000 18080 9090 5432; do
  ss -tlnH 2>/dev/null | grep -q ":$p " && PORTS_BUSY="$PORTS_BUSY $p"
done

# --- Outbound connectivity (release download) ---
GH="no"
curl -fsSL -I -m 8 https://github.com/NexusQuantum/NQRust-MicroVM/releases/latest/download/nqr-installer-x86_64-linux-musl >/dev/null 2>&1 && GH="yes"

# --- Prior install + tmux + sudo ---
PRIOR="none"
{ systemctl list-unit-files 2>/dev/null | grep -qE 'nqrust-(manager|agent)\.service' || [ -d /opt/nqrust-microvm ]; } && PRIOR="present"
TMUX="$(command -v tmux >/dev/null 2>&1 && echo present || echo missing)"
SUDO="$(sudo -n true 2>/dev/null && echo nopasswd || echo password)"

# --- hard-blocker summary (installer pre-flight equivalents) ---
BLOCKERS=""
[ "$ARCH" = "x86_64" ] || BLOCKERS="$BLOCKERS arch=$ARCH"
[ "$KVM" = "present" ] || BLOCKERS="$BLOCKERS no-kvm"
[ "${VIRT_FLAGS:-0}" -ge 1 ] 2>/dev/null || BLOCKERS="$BLOCKERS no-virt-flags"
[ "${DISK_FREE_GB:-0}" -ge 20 ] 2>/dev/null || BLOCKERS="$BLOCKERS disk<20G"
[ "$OS_SUPPORTED" = "no" ] && BLOCKERS="$BLOCKERS unsupported-os"

say ""
say "=== DISCOVERY ==="
say "HOSTNAME=$(hostname 2>/dev/null)"
say "OS=$OS_PRETTY"
say "OS_ID=$OS_ID"
say "OS_VERSION=$OS_VER"
say "OS_SUPPORTED=$OS_SUPPORTED"
say "ARCH=$ARCH"
say "KERNEL=$KERNEL"
say "VIRTUALIZED=$VIRTUALIZED"
say "CPU_CORES=$CPU_CORES"
say "CPU_MODEL=$CPU_MODEL"
say "VIRT=$VIRT_TYPE"
say "VIRT_FLAGS=$VIRT_FLAGS"
say "KVM=$KVM"
say "RAM_GB=$RAM_GB"
say "DISK_TOTAL_GB=${DISK_TOTAL_GB:-0}"
say "DISK_FREE_GB=${DISK_FREE_GB:-0}"
say "SRV_FREE_GB=${SRV_FREE_GB:-0}"
say "PRIMARY_NIC=${UPLINK:-none}"
say "PRIMARY_IP=${PRIMARY_IP:-none}"
say "PRIMARY_IP_PRIVATE=$PRIV"
say "GATEWAY=${GW:-none}"
say "NIC_COUNT=$NIC_COUNT"
say "NICS=${NIC_LIST:-none}"
say "PORTS_BUSY=${PORTS_BUSY# }"
say "GITHUB_REACHABLE=$GH"
say "TMUX=$TMUX"
say "SUDO=$SUDO"
say "PRIOR_INSTALL=$PRIOR"
say "BLOCKERS=${BLOCKERS# }"
say "=== END DISCOVERY ==="
[ -z "$BLOCKERS" ]
