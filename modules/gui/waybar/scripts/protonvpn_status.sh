#!/usr/bin/env bash
active_connections="$(nmcli --terse --fields NAME,TYPE connection show --active 2>/dev/null || true)"

# Proton names its NetworkManager profile "ProtonVPN CC#NNN"; CC is the
# connected server's exit-country code, so use Proton's own metadata instead
# of trying to infer a country from the server IP.
country_code="$(awk -F: '
  $1 ~ /^ProtonVPN [A-Z][A-Z]#/ && ($2 == "wireguard" || $2 == "vpn") {
    sub(/^ProtonVPN /, "", $1)
    sub(/#.*/, "", $1)
    print $1
    exit
  }
' <<< "$active_connections")"

# Proton's WireGuard backend uses proton0. The sysfs check works without
# CAP_NET_ADMIN; wg is a useful fallback, and active VPN profiles cover OpenVPN.
# The Advanced kill-switch dummy profile is not a VPN profile or proton0.
if [[ -e /sys/class/net/proton0 ]] || wg show proton0 >/dev/null 2>&1 || [[ -n "$country_code" ]]; then
  if [[ -n "$country_code" ]]; then
    declare -A country_map=(
      [CH]=CHE [DE]=DEU [SE]=SWE [PL]=POL [US]=USA [RO]=ROU
    )
    country="${country_map[$country_code]:-$country_code}"
    echo "VPN [PROTON · $country]"
  else
    echo "VPN [PROTON]"
  fi
else
  echo "<span color='#B96B6B'>VPN [OFF]</span>"
fi
