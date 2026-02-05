#!/usr/bin/env bash

mapfile -t PROFILES < <(lact cli profile list)
CURRENT=$(lact cli profile get)

for i in "${!PROFILES[@]}"; do
   if [[ "${PROFILES[$i]}" == "${CURRENT}" ]]; then
       # loop logic
       NEXT_INDEX=$(( (i + 1) % ${#PROFILES[@]} ))
       NEXT_PROFILE="${PROFILES[$NEXT_INDEX]}"

       # skip default when iterating  
       if [[ "$NEXT_PROFILE" == "Default" ]]; then
           NEXT_INDEX=$(( (NEXT_INDEX + 1) % ${#PROFILES[@]} ))
           NEXT_PROFILE="${PROFILES[$NEXT_INDEX]}"
       fi
       
       lact cli profile set "$NEXT_PROFILE"
       
       # refresh waybar instantlyc
       pkill -RTMIN+8 waybar
       exit 0
   fi
done
