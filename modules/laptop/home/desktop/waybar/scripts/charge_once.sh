#!/usr/bin/env bash
# Force a charge cycle to the stop threshold on both batteries.
# Requires a sudoers rule for tlp chargeonce (see modules/laptop/system/power.nix).
sudo tlp chargeonce BAT0 2>/dev/null || true
sudo tlp chargeonce BAT1 2>/dev/null || true
