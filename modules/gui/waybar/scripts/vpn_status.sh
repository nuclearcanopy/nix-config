#!/usr/bin/env bash
MOVING_FLAG="${XDG_STATE_HOME:-$HOME/.local/state}/vpn-moving"
if [[ -f "$MOVING_FLAG" ]]; then
  echo "<span color='#C6A857'>MOVING..</span>"
  exit 0
fi

status=$(mullvad status 2>/dev/null)

declare -A country_map=(
  [al]=ALB [at]=AUT [au]=AUS [be]=BEL [bg]=BGR [br]=BRA
  [ca]=CAN [ch]=CHE [cy]=CYP [cz]=CZE [de]=DEU [dk]=DNK
  [ee]=EST [es]=ESP [fi]=FIN [fr]=FRA [gb]=GBR [gr]=GRC
  [hk]=HKG [hr]=HRV [hu]=HUN [id]=IDN [ie]=IRL [il]=ISR
  [in]=IND [is]=ISL [it]=ITA [jp]=JPN [kr]=KOR [lt]=LTU
  [lu]=LUX [lv]=LVA [md]=MDA [mk]=MKD [mt]=MLT [mx]=MEX
  [my]=MYS [ng]=NGA [nl]=NLD [no]=NOR [nz]=NZL [ph]=PHL
  [pl]=POL [pt]=PRT [ro]=ROU [rs]=SRB [se]=SWE [sg]=SGP
  [si]=SVN [sk]=SVK [th]=THA [tr]=TUR [ua]=UKR [us]=USA
  [za]=ZAF
)

c() { printf '<span color="%s">%s</span>' "$1" "$2"; }

# Low-saturation flag palette
r="#b97070"  # red
w="#c8c8c8"  # white
k="#606060"  # black
y="#b8a870"  # gold/yellow
b="#7088b9"  # blue

flag_colored() {
  case "$1" in
    CHE) printf '%s%s%s' "$(c $r C)" "$(c $w H)" "$(c $r E)" ;;  # red  white red
    DEU) printf '%s%s%s' "$(c $k D)" "$(c $r E)" "$(c $y U)" ;;  # black red  gold
    SWE) printf '%s%s%s' "$(c $b S)" "$(c $y W)" "$(c $b E)" ;;  # blue yellow blue
    POL) printf '%s%s%s' "$(c $r P)" "$(c $w O)" "$(c $w L)" ;;  # red  white white
    USA) printf '%s%s%s' "$(c $b U)" "$(c $r S)" "$(c $w A)" ;;  # blue red   white
    *)   printf '%s' "$1" ;;
  esac
}

if [[ "$status" == Connected* ]]; then
  relay=""
  while read -r key val _; do
    if [[ "$key" == "Relay:" ]]; then
      relay="$val"
      break
    fi
  done <<< "$status"
  cc="${relay%%-*}"
  cc="${cc,,}"
  code="${country_map[${cc:-xx}]:-???}"
  echo "VPN [$(flag_colored "$code")]"
else
  echo "<span color='#B96B6B'>VPN [OFF]</span>"
fi
