# battery runtime estimation (nidhoggr)

`battery-model.service` (`modules/power/battery-model.nix`, script at `modules/power/scripts/battery_model.py`) replaces the old waybar arithmetic, which divided remaining charge by `current_now * voltage_now`. that's an instantaneous number, so the eta swung between ~2h and ~11h depending on what happened in the last five seconds, and was systematically wrong in both directions: a blanked screen extrapolated to 20+ hours, a compile burst to under two.

## how it works

it samples ~35 power-relevant signals every 5s (both packs' charge/current/voltage, rapl package + psys, cpu busy/sys/iowait, cpufreq, igpu freq, core temp, fan rpm, backlight, drm connector dpms, net/disk throughput, wifi/bt rfkill, cpu-mode, dominant process by cpu share), aggregates per minute, and learns the **distribution of mean power over the next n minutes** (n = 5/15/30/60/120/240/480) conditioned on that state. the eta then solves `integral(P_forecast) = usable energy` instead of assuming constant power.

- **conditioning is hierarchical.** state key is cpu-mode | screen state | power band | workload class | 3h time bucket | weekday-vs-weekend; each coarser level drops one variable down to a global `*`. prediction blends from the coarsest populated ancestor down to the most specific key with data, weighted by `n/(n+6)`, so a state seen twice still gets a sane answer instead of an overfit one. pruning a rare key (`MAX_KEYS = 4000`, lowest-evidence first) is safe because it degrades to its parent rather than vanishing.
- **workload class** comes from `/proc/<pid>/stat` comm prefixes (game/build/browser/media/ai/term/other). comm is truncated to 15 chars by the kernel and attacker-controlled via `prctl`, hence the prefix matching and a translate table scrubbing tabs/pipes that would desync the tsv/key separator.
- **persistence blend.** short horizons weight the measured current draw, long ones weight the learned distribution, crossing over at a time constant `tau` learned from the lag-15min autocorrelation of on-battery power. on a machine that switches tasks constantly, `tau` collapses to its 3min floor and the model essentially ignores the instantaneous reading; that's correct, not a bug.
- **charging** uses the same machinery against observed charge rate as a function of soc, capturing the cc/cv taper and the bat0-then-bat1 power bridge order for free. target is read from `charge_control_end_threshold`, so it reports time-to-80%, not time-to-100%.
- **the "empty" floor is learned, not assumed**, from how low the pack has actually gone while still running. it's the third-smallest run minimum, **not a percentile over all runs**: most discharge runs end because the charger went in, so their minima carry no information about where the machine dies, and a percentile over all of them lands far too high (it did, in testing: the floor exceeded current charge and zeroed the eta). the trainer retains the 100 *deepest* run minima, not the most recent.
- **current-sense calibration.** `current_now * voltage_now` is an ec estimate; the honest number is energy actually removed from the pack over a long window. the daemon compares the two over 30min windows and keeps a running correction factor (clamped 0.75-1.35).
- **energy uses `voltage_min_design`, not `voltage_now`.** instantaneous voltage sags several hundred mv under load, moving `charge * V_now` by ~5% for reasons unrelated to stored energy.
- **s3 drain is measured**, by diffing `CLOCK_BOOTTIME` against `CLOCK_MONOTONIC` to detect the sleep and taking the energy delta across it. the unit must not be stopped for suspend.

## storage and cost

`/var/lib/battery-model`: `minutes.tsv` is the training set (~260kb/day, kept forever; model rebuilds from it if `model.json` is missing or `MODEL_VERSION` moved), `raw/raw-DATE.tsv.gz` is the full 5s-resolution log rotated daily and gzipped, capped at 2gb (`BATTERY_MODEL_RAW_CAP`, ~4 years). histogram bins decay with a 45-day half-life, so the model tracks changing habits and pack ageing instead of averaging over all history.

runs as root: `intel-rapl` `energy_uj` is `0400 root` (a 2020 side-channel fix) and psys is the closest thing the t480 has to a whole-package power meter. cost is ~13ms cpu per 5s tick, 0.26% of one core.

## operating it

`battery-model status` prints the current estimate; `battery-model report` replays the whole history and prints per-horizon accuracy against the naive estimator it replaced, draw by regime, the charge curve, and measured s3 drain. **use `report` to check the model is actually earning its keep** before tuning anything.

the waybar script is only a relay: it `cat`s `waybar.json` if under 120s old, otherwise falls back to the original self-contained sysfs arithmetic with `class: stale` and a tooltip pointing at `systemctl status battery-model`. the module is `return-type = "json"` with `tooltip = true`; the tooltip is built in python next to the data that feeds it. don't reintroduce formatting logic into `battery.sh`.
