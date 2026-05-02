#!/usr/bin/env bash
# Display current platform profile (set by Fn+Q or TLP)
PROFILE_FILE="/sys/firmware/acpi/platform_profile"
PROFILE=$(cat "$PROFILE_FILE" 2>/dev/null || echo "unknown")

case "$PROFILE" in
  low-power)     printf "<span color='#758d5a'>PWS</span>\n" ;;
  balanced)      printf "BAL\n" ;;
  performance)   printf "<span color='#B96B6B'>PRF</span>\n" ;;
  *)             printf "%s\n" "$PROFILE" ;;
esac
