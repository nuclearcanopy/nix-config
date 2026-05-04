#!/usr/bin/env bash
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

if echo "$status" | grep -q "^Connected"; then
  relay=$(echo "$status" | awk '/Relay:/ { print $2 }')
  cc=$(echo "$relay" | cut -d'-' -f1 | tr '[:upper:]' '[:lower:]')
  code="${country_map[$cc]:-???}"
  echo "VPN [${code}]"
else
  echo "<span color='#B96B6B'>VPN [OFF]</span>"
fi
