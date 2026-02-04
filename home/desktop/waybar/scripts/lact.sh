#!/usr/bin/env bash

# Get list of profiles into an array
mapfile -t PROFILES < <(lact cli profile list)
# Get current profile
CURRENT=$(lact cli profile get)

# Find index of current profile
for i in "${!PROFILES[@]}"; do
   if [[ "${PROFILES[$i]}" == "${CURRENT}" ]]; then
       # Calculate next index (loops back to 0)
       NEXT_INDEX=$(( (i + 1) % ${#PROFILES[@]} ))
       NEXT_PROFILE="${PROFILES[$NEXT_INDEX]}"

       # If the next profile is "default", skip to the one after it
       if [[ "$NEXT_PROFILE" == "Default" ]]; then
           NEXT_INDEX=$(( (NEXT_INDEX + 1) % ${#PROFILES[@]} ))
           NEXT_PROFILE="${PROFILES[$NEXT_INDEX]}"
       fi
       
       # Apply next profile
       lact cli profile set "$NEXT_PROFILE"
       
       # Send signal to waybar to refresh the module immediately
       pkill -RTMIN+8 waybar
       exit 0
   fi
done
