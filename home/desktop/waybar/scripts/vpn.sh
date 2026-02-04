#!/usr/bin/env bash

RAW_STATUS=$(mullvad status)

LOCATION=$(echo "$RAW_STATUS" | awk '/Relay:/ {print $NF}')

CLEAN_STATUS=$(echo "$RAW_STATUS" | tr '\n' ' ' | sed 's/  */ /g')

if [[ "$RAW_STATUS" == "Connected"* ]]; then
    TOOLTIP=${LOCATION:-$CLEAN_STATUS}
    echo "{\"text\": \" \", \"class\": \"connected\", \"tooltip\": \"$TOOLTIP\"}"
else
    echo "{\"text\": \" \", \"class\": \"disconnected\", \"tooltip\": \"Disconnected\"}"
fi
