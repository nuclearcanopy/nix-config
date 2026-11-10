#!/usr/bin/env bash
active_vpn="$(nmcli --terse --fields TYPE connection show --active 2>/dev/null || true)"

# Proton's WireGuard backend uses proton0. The sysfs check works without
# CAP_NET_ADMIN; wg is a useful fallback, and active VPN profiles cover OpenVPN.
# The Advanced kill-switch dummy profile is not a VPN profile or proton0.
if [[ -e /sys/class/net/proton0 ]] || wg show proton0 >/dev/null 2>&1 || grep -qx 'vpn' <<< "$active_vpn"; then
  echo "VPN [PROTON]"
else
  echo "<span color='#B96B6B'>VPN [OFF]</span>"
fi
