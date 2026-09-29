#!/usr/bin/env python3
"""Adaptive battery runtime estimator for nidhoggr (ThinkPad T480, dual pack).

Instead of dividing remaining charge by the instantaneous current (which the
naive waybar script did, and which swings between 2h and 11h depending on what
happened in the last five seconds), this samples a wide slice of the machine's
power-relevant state a few times a minute, keeps a long compressed history of
it, and learns what the power draw actually *does over the next N minutes*
given a state like the current one.

Three layers:

  1. Sampler       - every SAMPLE_SEC, read battery/psys/RAPL/cpu/gpu/display/
                     net/disk/radio state, write a raw TSV row.
  2. History       - per-minute aggregates in minutes.tsv (the training set,
                     kept forever), raw rows in raw/raw-DATE.tsv.gz (kept to a
                     byte cap, for re-deriving the model later).
  3. Forecast      - hierarchical time-decayed histograms of "mean power over
                     the next H minutes", conditioned on cpu-mode, screen
                     state, current power band, workload class, hour of day
                     and weekday/weekend, with shrinkage from specific to
                     general so a state seen twice still gets a sane answer.
                     The ETA solves  integral(P_forecast) = usable energy
                     rather than assuming power is constant.

Charging uses the same idea against a different variable: observed combined
charge rate as a function of state of charge, which captures the CC/CV taper
and the sequential BAT0-then-BAT1 order of the Power Bridge for free.

Everything is stdlib: no numpy, no scipy. The daemon is ~0.3% of one core.

Usage:
  battery_model.py daemon     sample, learn, write estimate files (the service)
  battery_model.py status     print the current estimate
  battery_model.py report     print what the model has learned
  battery_model.py rebuild    rebuild model.json from minutes.tsv, then exit
"""

import glob
import gzip
import json
import math
import os
import shutil
import signal
import sys
import time

# ─────────────────────────────── configuration ───────────────────────────────

STATE_DIR = os.environ.get("BATTERY_MODEL_DIR", "/var/lib/battery-model")
RAW_DIR = os.path.join(STATE_DIR, "raw")

SAMPLE_SEC = float(os.environ.get("BATTERY_MODEL_INTERVAL", "5"))
PROC_EVERY = 3                      # scan /proc/*/stat every Nth sample
RAW_CAP_BYTES = int(os.environ.get("BATTERY_MODEL_RAW_CAP", str(2 * 1024**3)))
MINUTES_CAP_BYTES = 512 * 1024**2   # ~10 years; rotates rather than truncates

MODEL_VERSION = 3
HALF_LIFE_DAYS = float(os.environ.get("BATTERY_MODEL_HALF_LIFE", "45"))
SHRINK_K = 6.0                      # pseudo-counts pulling a level to its parent
HORIZONS = (5, 15, 30, 60, 120, 240, 480)   # minutes
PBIN = 0.25                         # watt-resolution of the histograms
PMAX = 80.0
MIN_DECAY_DT = 6 * 3600             # only re-decay a histogram this far apart
MAX_KEYS = 4000                     # conditioned states retained in model.json
PERSIST_TAU_DEFAULT = 18.0          # minutes; overwritten by learned value
EMA_TAU_SEC = 90.0                  # smoothing of "power right now"
FLOOR_FRACTION_DEFAULT = 0.04       # reserve below which the machine dies

# ──────────────────────────────── sysfs helpers ──────────────────────────────


def rd(path):
    try:
        with open(path, "rb") as f:
            return f.read().strip().decode("utf-8", "replace")
    except OSError:
        return None


def rdi(path, default=None):
    v = rd(path)
    if v is None:
        return default
    try:
        return int(v)
    except ValueError:
        return default


def hwmon_by_name(name):
    for h in sorted(glob.glob("/sys/class/hwmon/hwmon*")):
        if rd(os.path.join(h, "name")) == name:
            return h
    return None


def atomic_write(path, text):
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        f.write(text)
    os.replace(tmp, path)
    try:
        os.chmod(path, 0o644)
    except OSError:
        pass


# ──────────────────────────────── workload class ─────────────────────────────

# /proc/<pid>/stat comm is truncated to 15 chars, so match on prefixes.
CLASS_PREFIXES = (
    ("game", ("java", "prismlauncher", "steam", "bolt", "wine", "gamescope",
              "minecraft", "proton")),
    ("build", ("cc1", "cc1plus", "gcc", "clang", "rustc", "cargo", "ld", "lld",
               "nix", "nix-build", "nix-daemon", "make", "ninja", "cmake",
               "bwrap", "go", "tsc", "webpack", "esbuild")),
    ("browser", ("firefox", "Web Content", "Isolated Web", "WebExtensions",
                 "RDD Process", "Utility Process", "Privileged Cont", "helium",
                 "chromium", "chrome", "discord", "Discord")),
    ("media", ("mpv", "vlc", "ffmpeg", "obs", "gst", "termsonic", "easyeffects",
               "pipewire", "wireplumber", "spotify")),
    ("ai", ("claude", "node", "ollama", "python3")),
    ("term", ("nvim", "zsh", "alacritty", "rg", "fd", "git")),
)


COMM_SCRUB = str.maketrans({"\t": " ", "\n": " ", "\r": " ", "|": "_", '"': "'",
                            "\\": "_"})


def classify(comm):
    if not comm:
        return "idle"
    for cls, prefixes in CLASS_PREFIXES:
        for p in prefixes:
            if comm.startswith(p):
                return cls
    return "other"


# ──────────────────────────────── the sampler ────────────────────────────────


class Sampler:
    """Reads one full state vector of the machine per call."""

    def __init__(self):
        self.bats = sorted(
            b for b in glob.glob("/sys/class/power_supply/BAT*")
            if rdi(os.path.join(b, "present"), 1) == 1
        )
        # Nominal voltage for energy accounting. Instantaneous voltage sags
        # several hundred mV under load, which makes charge*V_now jump around
        # by ~5% for reasons that have nothing to do with stored energy.
        self.vnom = {}
        self.design = {}
        for b in self.bats:
            self.vnom[b] = (rdi(os.path.join(b, "voltage_min_design")) or
                            rdi(os.path.join(b, "voltage_now")) or 11400000) / 1e6
            cfd = rdi(os.path.join(b, "charge_full_design"))
            self.design[b] = (cfd / 1e6 * self.vnom[b]) if cfd else 0.0

        self.ac = "/sys/class/power_supply/AC"
        self.coretemp = hwmon_by_name("coretemp")
        self.thinkpad = hwmon_by_name("thinkpad")
        self.gpu = "/sys/class/drm/card1"
        if not os.path.exists(os.path.join(self.gpu, "gt_act_freq_mhz")):
            cards = glob.glob("/sys/class/drm/card*/gt_act_freq_mhz")
            self.gpu = os.path.dirname(cards[0]) if cards else None

        self.rapl = {}
        for d in glob.glob("/sys/class/powercap/intel-rapl:*"):
            n = rd(os.path.join(d, "name"))
            if n in ("package-0", "psys") and os.access(
                    os.path.join(d, "energy_uj"), os.R_OK):
                self.rapl[n] = (os.path.join(d, "energy_uj"),
                                rdi(os.path.join(d, "max_energy_range_uj"), 0))

        self.connectors = sorted(glob.glob("/sys/class/drm/card*-*"))
        self.backlights = sorted(glob.glob("/sys/class/backlight/*"))

        self.prev = {}          # counters from the previous sample
        self.proc_prev = {}
        self.proc_countdown = 0
        self.top = ("", 0.0)
        self.clk = os.sysconf("SC_CLK_TCK")
        self.ncpu = os.cpu_count() or 4

    # -- individual probes ---------------------------------------------------

    def cpu_stat(self):
        line = rd("/proc/stat")
        if not line:
            return None
        parts = line.split("\n", 1)[0].split()[1:]
        v = [int(x) for x in parts[:8]]
        return {"total": sum(v), "idle": v[3], "iowait": v[4], "sys": v[2] + v[5] + v[6]}

    def cpu_freq(self):
        tot = n = 0
        for p in glob.glob("/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq"):
            f = rdi(p)
            if f:
                tot += f
                n += 1
        return (tot / n / 1000.0) if n else 0.0

    def rapl_energy(self):
        out = {}
        for name, (path, wrap) in self.rapl.items():
            e = rdi(path)
            if e is not None:
                out[name] = (e, wrap)
        return out

    def net_bytes(self):
        tot = 0
        txt = rd("/proc/net/dev") or ""
        for line in txt.split("\n")[2:]:
            if ":" not in line:
                continue
            name, rest = line.split(":", 1)
            name = name.strip()
            if name == "lo" or name.startswith(("docker", "veth", "br-")):
                continue
            f = rest.split()
            if len(f) >= 9:
                tot += int(f[0]) + int(f[8])
        return tot

    def disk_bytes(self):
        tot = 0
        txt = rd("/proc/diskstats") or ""
        for line in txt.split("\n"):
            f = line.split()
            if len(f) < 10:
                continue
            name = f[2]
            if not (name.startswith("nvme") and "p" not in name[4:]):
                continue
            tot += (int(f[5]) + int(f[9])) * 512
        return tot

    def displays(self):
        """(screen_state, external_count). 0 = blanked, 1 = internal, 2 = external."""
        ext = 0
        internal_on = False
        any_on = False
        for c in self.connectors:
            if rd(os.path.join(c, "enabled")) != "enabled":
                continue
            dpms = rd(os.path.join(c, "dpms"))
            on = dpms != "Off"
            if "eDP" in c or "LVDS" in c:
                internal_on = internal_on or on
            elif on:
                ext += 1
            any_on = any_on or on
        # A blanked backlight is the cheapest reliable "screen off" signal on
        # the internal panel; DPMS alone lags on some sway blank paths.
        for b in self.backlights:
            if rdi(os.path.join(b, "bl_power"), 0) not in (0, None):
                internal_on = False
        if ext:
            return 2, ext
        if internal_on and any_on:
            return 1, 0
        return 0, ext

    def backlight_pct(self):
        for b in self.backlights:
            cur = rdi(os.path.join(b, "actual_brightness"))
            mx = rdi(os.path.join(b, "max_brightness"))
            if cur is not None and mx:
                if rdi(os.path.join(b, "bl_power"), 0) not in (0, None):
                    return 0
                return int(cur * 100 / mx)
        return -1

    def radios(self):
        wifi = bt = 0
        for r in glob.glob("/sys/class/rfkill/rfkill*"):
            t = rd(os.path.join(r, "type"))
            blocked = (rdi(os.path.join(r, "soft"), 0) or
                       rdi(os.path.join(r, "hard"), 0))
            if t == "wlan" and not blocked:
                wifi = 1
            elif t == "bluetooth" and not blocked:
                bt = 1
        return wifi, bt

    def audio_active(self):
        for s in glob.glob("/proc/asound/card*/pcm*/sub*/status"):
            st = rd(s)
            if st and st.startswith("state: RUNNING"):
                return 1
        return 0

    def top_proc(self, dt):
        """Dominant process by CPU share since the last scan. Sampled, not free."""
        cur = {}
        best_name, best = "", 0.0
        for d in os.listdir("/proc"):
            if not d.isdigit():
                continue
            st = rd("/proc/%s/stat" % d)
            if not st:
                continue
            close = st.rfind(")")
            if close < 0:
                continue
            # comm is attacker-controlled (prctl) and may contain tabs, which
            # would desynchronise the TSV, or pipes, which would collide with
            # the state-key separator.
            comm = st[st.find("(") + 1:close].translate(COMM_SCRUB)
            f = st[close + 2:].split()
            if len(f) < 13:
                continue
            j = int(f[11]) + int(f[12])          # utime + stime
            cur[d] = (comm, j)
            prev = self.proc_prev.get(d)
            if prev and prev[0] == comm:
                share = (j - prev[1]) / self.clk / max(dt, 0.1)
                if share > best:
                    best, best_name = share, comm
        self.proc_prev = cur
        return best_name, round(min(best, self.ncpu), 3)

    # -- one sample ----------------------------------------------------------

    def sample(self, now, dt):
        s = {"ts": round(now, 1)}

        e_wh = e_full_wh = 0.0
        p_batt = 0.0
        charging = discharging = False
        per_bat = []
        for b in self.bats:
            st = rd(os.path.join(b, "status")) or "Unknown"
            cn = rdi(os.path.join(b, "charge_now"))
            cf = rdi(os.path.join(b, "charge_full"))
            v = rdi(os.path.join(b, "voltage_now")) or 0
            i = rdi(os.path.join(b, "current_now")) or 0
            if cn is None or not cf:
                en, ef = rdi(os.path.join(b, "energy_now")), rdi(os.path.join(b, "energy_full"))
                pw = rdi(os.path.join(b, "power_now")) or 0
                if en is None or not ef:
                    continue
                e_wh += en / 1e6
                e_full_wh += ef / 1e6
                w = pw / 1e6
            else:
                vn = self.vnom[b]
                e_wh += cn / 1e6 * vn
                e_full_wh += cf / 1e6 * vn
                w = i / 1e6 * (v / 1e6 if v else vn)
            if st == "Charging":
                charging = True
                p_batt -= w
            elif st == "Discharging":
                discharging = True
                p_batt += w
            per_bat.append((v / 1e6, i / 1e6, (cn or 0) / 1e6))

        s["e_wh"] = round(e_wh, 3)
        s["e_full_wh"] = round(e_full_wh, 3)
        s["soc"] = round(100.0 * e_wh / e_full_wh, 2) if e_full_wh else 0.0
        s["p_batt_w"] = round(p_batt, 3)
        s["ac"] = rdi(os.path.join(self.ac, "online"), 0) or 0
        s["st"] = "C" if charging else ("D" if discharging else ("F" if s["ac"] else "U"))
        for idx in range(2):
            v, i, c = per_bat[idx] if idx < len(per_bat) else (0.0, 0.0, 0.0)
            s["v%d" % idx] = round(v, 3)
            s["i%d" % idx] = round(i, 3)
            s["c%d" % idx] = round(c, 3)

        c = self.cpu_stat()
        pc = self.prev.get("cpu")
        if c and pc and c["total"] > pc["total"]:
            d_tot = c["total"] - pc["total"]
            s["cpu"] = round(100.0 * (1 - (c["idle"] - pc["idle"] +
                                           c["iowait"] - pc["iowait"]) / d_tot), 2)
            s["cpu_sys"] = round(100.0 * (c["sys"] - pc["sys"]) / d_tot, 2)
            s["cpu_io"] = round(100.0 * (c["iowait"] - pc["iowait"]) / d_tot, 2)
        else:
            s["cpu"] = s["cpu_sys"] = s["cpu_io"] = 0.0
        self.prev["cpu"] = c

        s["freq"] = round(self.cpu_freq(), 0)

        rapl = self.rapl_energy()
        prev_rapl = self.prev.get("rapl") or {}
        for key, col in (("package-0", "rapl_pkg_w"), ("psys", "rapl_psys_w")):
            s[col] = -1.0
            if key in rapl and key in prev_rapl and dt > 0:
                e, wrap = rapl[key]
                pe = prev_rapl[key][0]
                d = e - pe
                if d < 0 and wrap:
                    d += wrap
                if 0 <= d < 500e6:
                    s[col] = round(d / 1e6 / dt, 3)
        self.prev["rapl"] = rapl

        s["gpu_mhz"] = rdi(os.path.join(self.gpu, "gt_act_freq_mhz"), 0) if self.gpu else 0
        s["temp_c"] = round((rdi(os.path.join(self.coretemp, "temp1_input"), 0) or 0) / 1000.0, 1) \
            if self.coretemp else 0.0
        s["fan"] = rdi(os.path.join(self.thinkpad, "fan1_input"), 0) if self.thinkpad else 0

        s["bl"] = self.backlight_pct()
        s["scr"], s["ext"] = self.displays()

        nb, db = self.net_bytes(), self.disk_bytes()
        pn, pd = self.prev.get("net"), self.prev.get("disk")
        s["net_kbps"] = round(max(0, nb - pn) / 1024.0 / dt, 1) if pn is not None and dt > 0 else 0.0
        s["dsk_kbps"] = round(max(0, db - pd) / 1024.0 / dt, 1) if pd is not None and dt > 0 else 0.0
        self.prev["net"], self.prev["disk"] = nb, db

        s["wifi"], s["bt"] = self.radios()
        s["audio"] = self.audio_active()
        s["mode"] = rd("/var/lib/cpu-mode/state") or "auto"

        self.proc_countdown -= 1
        if self.proc_countdown <= 0:
            self.proc_countdown = PROC_EVERY
            self.top = self.top_proc(dt * PROC_EVERY)
        s["top"], s["top_sh"] = self.top

        return s


RAW_COLS = ("ts", "ac", "st", "soc", "e_wh", "e_full_wh", "p_batt_w",
            "v0", "i0", "c0", "v1", "i1", "c1",
            "cpu", "cpu_sys", "cpu_io", "freq", "rapl_pkg_w", "rapl_psys_w",
            "gpu_mhz", "temp_c", "fan", "bl", "scr", "ext", "net_kbps",
            "dsk_kbps", "wifi", "bt", "audio", "mode", "top", "top_sh", "gap")

MIN_COLS = ("ts", "n", "ac", "st", "soc", "e_wh", "e_full_wh", "p_batt_w",
            "cpu", "cpu_sys", "freq", "rapl_pkg_w", "rapl_psys_w", "gpu_mhz",
            "temp_c", "fan", "bl", "scr", "ext", "net_kbps", "dsk_kbps",
            "wifi", "bt", "audio", "mode", "top", "gap")

MEAN_COLS = ("soc", "e_wh", "e_full_wh", "p_batt_w", "cpu", "cpu_sys", "freq",
             "rapl_pkg_w", "rapl_psys_w", "gpu_mhz", "temp_c", "fan", "bl",
             "net_kbps", "dsk_kbps")
MODE_COLS = ("st", "mode", "top", "scr", "ext", "wifi", "bt", "audio", "ac")

# rapl_pkg_w/rapl_psys_w use -1.0 to mean "not readable this tick" (see
# Sampler.sample); p_batt_w is legitimately negative while charging, so it
# must not be caught by that sentinel filter or every charging minute
# averages to 0.0 and the charge-rate model never learns anything.
RAPL_SENTINEL_COLS = ("rapl_pkg_w", "rapl_psys_w")


# ──────────────────────────────── the log files ──────────────────────────────


class Logs:
    def __init__(self):
        os.makedirs(RAW_DIR, exist_ok=True)
        self.raw = None
        self.raw_day = None
        self.minutes_path = os.path.join(STATE_DIR, "minutes.tsv")
        if not os.path.exists(self.minutes_path):
            with open(self.minutes_path, "w") as f:
                f.write("#" + "\t".join(MIN_COLS) + "\n")
        self.minutes = open(self.minutes_path, "a")

    def write_raw(self, s):
        day = time.strftime("%Y-%m-%d", time.localtime(s["ts"]))
        if day != self.raw_day:
            self._roll(day)
        self.raw.write("\t".join(str(s.get(c, "")) for c in RAW_COLS) + "\n")

    def _roll(self, day):
        if self.raw:
            self.raw.close()
            old = os.path.join(RAW_DIR, "raw-%s.tsv" % self.raw_day)
            if os.path.exists(old):
                try:
                    with open(old, "rb") as fi, gzip.open(old + ".gz", "wb", 6) as fo:
                        shutil.copyfileobj(fi, fo)
                    os.unlink(old)
                except OSError:
                    pass
        self.raw_day = day
        path = os.path.join(RAW_DIR, "raw-%s.tsv" % day)
        new = not os.path.exists(path)
        self.raw = open(path, "a")
        if new:
            self.raw.write("#" + "\t".join(RAW_COLS) + "\n")
        self.enforce_cap()

    def enforce_cap(self):
        files = sorted(glob.glob(os.path.join(RAW_DIR, "raw-*.tsv*")))
        total = sum(os.path.getsize(f) for f in files if os.path.exists(f))
        for f in files[:-1]:
            if total <= RAW_CAP_BYTES:
                break
            try:
                total -= os.path.getsize(f)
                os.unlink(f)
            except OSError:
                pass
        if os.path.getsize(self.minutes_path) > MINUTES_CAP_BYTES:
            self.minutes.close()
            os.replace(self.minutes_path,
                       os.path.join(RAW_DIR, "minutes-%s.tsv" % self.raw_day))
            with open(self.minutes_path, "w") as f:
                f.write("#" + "\t".join(MIN_COLS) + "\n")
            self.minutes = open(self.minutes_path, "a")

    def write_minute(self, rec):
        self.minutes.write("\t".join(str(rec.get(c, "")) for c in MIN_COLS) + "\n")
        self.minutes.flush()

    def flush(self):
        for f in (self.raw, self.minutes):
            if f:
                try:
                    f.flush()
                except OSError:
                    pass


def read_minutes(limit_days=None):
    """Stream minutes.tsv as dicts, oldest first."""
    path = os.path.join(STATE_DIR, "minutes.tsv")
    if not os.path.exists(path):
        return
    cutoff = time.time() - limit_days * 86400 if limit_days else 0
    with open(path) as f:
        for line in f:
            if line.startswith("#"):
                continue
            f_ = line.rstrip("\n").split("\t")
            if len(f_) != len(MIN_COLS):
                continue
            rec = dict(zip(MIN_COLS, f_))
            try:
                rec["ts"] = float(rec["ts"])
            except ValueError:
                continue
            if rec["ts"] < cutoff:
                continue
            for c in MEAN_COLS + ("n", "gap"):
                try:
                    rec[c] = float(rec[c])
                except (ValueError, KeyError):
                    rec[c] = 0.0
            for c in ("scr", "ext", "wifi", "bt", "audio", "ac"):
                try:
                    rec[c] = int(float(rec[c]))
                except (ValueError, KeyError):
                    rec[c] = 0
            yield rec


# ────────────────────────────── forecast model ───────────────────────────────


def pband(w):
    """Coarse power band of the recent draw. Conditioning on this is what makes
    the forecast aware of 'what kind of session is this' before anything else."""
    for i, edge in enumerate((3.5, 5.0, 7.0, 9.5, 13.0, 18.0, 25.0, 35.0)):
        if w < edge:
            return i
    return 8


def state_keys(rec, recent_w):
    """Most specific first. Each level drops one conditioning variable, so the
    shrinkage walk always has a populated ancestor to fall back on."""
    mode = rec.get("mode") or "auto"
    scr = rec.get("scr", 1)
    pb = pband(recent_w)
    cls = classify(rec.get("top"))
    lt = time.localtime(rec["ts"])
    h3 = lt.tm_hour // 3
    wk = 1 if lt.tm_wday >= 5 else 0
    return [
        "%s|%d|%d|%s|%d|%d" % (mode, scr, pb, cls, h3, wk),
        "%s|%d|%d|%s" % (mode, scr, pb, cls),
        "%s|%d|%d" % (mode, scr, pb),
        "*|%d|%d" % (scr, pb),
        "*|*|%d" % pb,
        "*",
    ]


class Hist:
    """Exponentially time-decayed weighted histogram over watts."""

    __slots__ = ("ts", "b")

    def __init__(self, ts=0.0, b=None):
        self.ts = ts
        self.b = b if b is not None else {}

    def decay(self, now):
        """Age the bins toward zero so old habits stop outvoting recent ones.

        Deferred rather than applied per add: rescaling every bin on every
        sample would be pure overhead, so we wait for MIN_DECAY_DT to pass and
        let the exponent absorb the whole interval at once. The error this
        introduces is one interval of un-applied decay, 0.4% at a 6h defer
        against a 45-day half-life.
        """
        if not self.b:
            self.ts = now
            return
        dt = now - self.ts
        if dt < MIN_DECAY_DT:
            return
        f = 0.5 ** (dt / (HALF_LIFE_DAYS * 86400))
        self.b = {k: v * f for k, v in self.b.items() if v * f > 2e-3}
        self.ts = now

    def add(self, now, watts, weight=1.0):
        self.decay(now)
        k = str(int(min(max(watts, 0.0), PMAX) / PBIN))
        self.b[k] = self.b.get(k, 0.0) + weight

    def total(self):
        return sum(self.b.values())

    def norm(self):
        t = self.total()
        if t <= 0:
            return None
        return {k: v / t for k, v in self.b.items()}


def blend(a, b, alpha):
    """alpha*a + (1-alpha)*b over sparse bin dicts."""
    out = {k: v * alpha for k, v in a.items()}
    for k, v in b.items():
        out[k] = out.get(k, 0.0) + v * (1 - alpha)
    return out


def quantile(dist, q):
    items = sorted(((int(k), v) for k, v in dist.items()))
    acc = 0.0
    for k, v in items:
        acc += v
        if acc >= q:
            return (k + 0.5) * PBIN
    return (items[-1][0] + 0.5) * PBIN if items else 0.0


class Model:
    def __init__(self):
        self.version = MODEL_VERSION
        self.fwd = {}        # key -> {horizon: Hist}  forward mean power
        self.chg = {}        # soc bucket (2%) -> Hist  charge power
        self.floor_wh = []   # lowest energy seen while still running, per run
        self.tau = PERSIST_TAU_DEFAULT
        self.calib = 1.0     # i*v -> true drain correction, learned from dE/dt
        self.calib_n = 0.0
        self.suspend = []    # (ts, hours, watts)
        self.acc = {h: [0.0, 0.0, 0.0] for h in HORIZONS}  # n, model MAE, naive MAE
        self.updated = 0.0
        self.minutes_seen = 0
        self.battery_minutes = 0

    # -- learning ------------------------------------------------------------

    def credit(self, now, keys, horizon, watts):
        for k in keys:
            d = self.fwd.setdefault(k, {})
            h = d.get(horizon)
            if h is None:
                h = d[horizon] = Hist(now)
            h.add(now, watts)

    def credit_charge(self, now, soc, watts):
        b = str(int(min(max(soc, 0.0), 100.0) / 2))
        h = self.chg.get(b)
        if h is None:
            h = self.chg[b] = Hist(now)
        h.add(now, watts)

    # -- prediction ----------------------------------------------------------

    def dist_for(self, keys, horizon):
        """Shrinkage blend from the coarsest populated ancestor down to the most
        specific key that has data. Returns (distribution, effective count)."""
        acc = None
        neff = 0.0
        for key in reversed(keys):
            h = self.fwd.get(key, {}).get(horizon)
            if h is None:
                continue
            n = h.total()
            if n <= 0:
                continue
            d = h.norm()
            if acc is None:
                acc = d
            else:
                acc = blend(d, acc, n / (n + SHRINK_K))
            neff = n
        return acc, neff

    def forecast(self, keys, p_now, quantile_q=0.5):
        """Mean power over each horizon, blending measured-now into learned."""
        out = {}
        conf = 0.0
        for h in HORIZONS:
            d, n = self.dist_for(keys, h)
            beta = math.exp(-h / max(self.tau, 1.0))
            if d is None:
                out[h] = p_now * (1.0 + (0.30 if quantile_q > 0.5 else
                                         (-0.30 if quantile_q < 0.5 else 0.0)))
            else:
                out[h] = beta * p_now + (1 - beta) * quantile(d, quantile_q)
                conf = max(conf, n)
        return out, conf

    # -- persistence ---------------------------------------------------------

    def prune(self, keep=MAX_KEYS):
        """Cap the number of conditioned states.

        The level-1 key space is mode x screen x power-band x class x hour x
        weekday, so it is finite but large, and a 45-day half-life keeps a bin
        alive for about a year. Drop the lowest-evidence keys first; every one
        of them still has a populated ancestor to shrink to, so dropping a
        rarely-seen state degrades it to the general answer rather than
        removing it from the model.
        """
        if len(self.fwd) <= keep:
            return
        ranked = sorted(self.fwd.items(),
                        key=lambda kv: -sum(h.total() for h in kv[1].values()))
        self.fwd = dict(ranked[:keep])

    def to_json(self):
        self.prune()
        return {
            "version": self.version,
            "updated": self.updated,
            "tau": self.tau,
            "calib": self.calib,
            "calib_n": self.calib_n,
            "floor_wh": sorted(self.floor_wh)[:100],
            "suspend": self.suspend[-200:],
            "acc": {str(k): v for k, v in self.acc.items()},
            "minutes_seen": self.minutes_seen,
            "battery_minutes": self.battery_minutes,
            "fwd": {k: {str(h): [hist.ts, hist.b] for h, hist in d.items()
                        if hist.total() > 0.02}
                    for k, d in self.fwd.items()
                    if any(x.total() > 0.02 for x in d.values())},
            "chg": {k: [h.ts, h.b] for k, h in self.chg.items() if h.total() > 0.02},
        }

    @classmethod
    def from_json(cls, data):
        m = cls()
        if data.get("version") != MODEL_VERSION:
            return None
        m.updated = data.get("updated", 0.0)
        m.tau = data.get("tau", PERSIST_TAU_DEFAULT)
        m.calib = data.get("calib", 1.0)
        m.calib_n = data.get("calib_n", 0.0)
        m.floor_wh = data.get("floor_wh", [])
        m.suspend = data.get("suspend", [])
        m.minutes_seen = data.get("minutes_seen", 0)
        m.battery_minutes = data.get("battery_minutes", 0)
        for k, v in data.get("acc", {}).items():
            try:
                m.acc[int(k)] = v
            except ValueError:
                pass
        for k, d in data.get("fwd", {}).items():
            m.fwd[k] = {int(h): Hist(v[0], v[1]) for h, v in d.items()}
        for k, v in data.get("chg", {}).items():
            m.chg[k] = Hist(v[0], v[1])
        return m


# ─────────────────────────────── model training ──────────────────────────────


class Trainer:
    """Feeds minute records into the model, both live and during a rebuild.

    A state's label is not known until the horizon has elapsed, so minutes are
    held in a ring and credited retroactively once a full, uninterrupted,
    on-battery window exists behind them.
    """

    def __init__(self, model, evaluate=False):
        self.m = model
        self.buf = []
        self.evaluate = evaluate
        self.eval_counter = 0
        self.run_min_wh = None
        self.recent = []           # (ts, watts) for the trailing-power band
        self.autocorr = [0.0, 0.0, 0.0]   # n, sum(x*y), sum(x^2) at lag 15min

    def feed(self, rec):
        self.m.minutes_seen += 1
        self.buf.append(rec)
        if len(self.buf) > max(HORIZONS) + 2:
            self.buf.pop(0)

        on_batt = rec["st"] == "D" and not rec["ac"]
        if on_batt:
            self.m.battery_minutes += 1
            if self.run_min_wh is None or rec["e_wh"] < self.run_min_wh:
                self.run_min_wh = rec["e_wh"]
        else:
            if self.run_min_wh is not None:
                self.m.floor_wh.append(round(self.run_min_wh, 2))
                # Retain the *deepest* runs, not the most recent: a run that
                # ended at 88 Wh because the charger went in carries no
                # information about where the machine dies, and evicting a
                # genuine near-flat run in its favour would raise the floor.
                self.m.floor_wh = sorted(self.m.floor_wh)[:100]
                self.run_min_wh = None
            if rec["st"] == "C" and rec["p_batt_w"] < 0:
                self.m.credit_charge(rec["ts"], rec["soc"], -rec["p_batt_w"])

        self._learn_tau(rec, on_batt)
        self._credit_windows(rec)

    def _learn_tau(self, rec, on_batt):
        if not on_batt:
            self.recent = []
            return
        self.recent.append((rec["ts"], rec["p_batt_w"]))
        if len(self.recent) > 16:
            self.recent.pop(0)
        if len(self.recent) == 16 and self.recent[-1][0] - self.recent[0][0] < 16 * 70:
            a = self.recent[0][1]
            b = self.recent[-1][1]
            mean = sum(x[1] for x in self.recent) / 16
            self.autocorr[0] += 1
            self.autocorr[1] += (a - mean) * (b - mean)
            self.autocorr[2] += (a - mean) ** 2

    def _trailing_power(self, idx, minutes=15):
        """Mean battery power over the `minutes` before buf[idx] (inclusive)."""
        lo = max(0, idx - minutes + 1)
        vals = [self.buf[i]["p_batt_w"] for i in range(lo, idx + 1)
                if self.buf[i]["st"] == "D"]
        return sum(vals) / len(vals) if vals else self.buf[idx]["p_batt_w"]

    def _credit_windows(self, rec):
        n = len(self.buf)
        for h in HORIZONS:
            idx = n - 1 - h
            if idx < 0:
                continue
            window = self.buf[idx:n]
            if len(window) != h + 1:
                continue
            ok = True
            total = 0.0
            for i in range(1, len(window)):
                w = window[i]
                if (w["ts"] - window[i - 1]["ts"] > 90 or w["gap"] or
                        w["st"] != "D" or w["ac"]):
                    ok = False
                    break
                total += w["p_batt_w"]
            if not ok or window[0]["st"] != "D":
                continue
            mean_w = total / h
            base = window[0]
            recent_w = self._trailing_power(idx)
            keys = state_keys(base, recent_w)

            if self.evaluate:
                self.eval_counter += 1
                if self.eval_counter % 10 == 0:
                    d, _ = self.m.dist_for(keys, h)
                    if d is not None:
                        beta = math.exp(-h / max(self.m.tau, 1.0))
                        pred = beta * recent_w + (1 - beta) * quantile(d, 0.5)
                        a = self.m.acc[h]
                        a[0] += 1
                        a[1] += abs(pred - mean_w)
                        a[2] += abs(recent_w - mean_w)

            self.m.credit(base["ts"], keys, h, mean_w)

    def finish(self):
        n, sxy, sxx = self.autocorr
        if n > 30 and sxx > 0:
            r = max(1e-3, min(0.995, sxy / sxx))
            # r is the correlation across a 15-minute lag; tau is the e-folding
            # time of the usage regime, which is what the persistence blend uses.
            self.m.tau = max(3.0, min(240.0, -15.0 / math.log(r)))


# ──────────────────────────────── the estimate ───────────────────────────────


def solve_eta(curve, energy_wh):
    """Minutes until `energy_wh` is consumed, given mean-power-over-horizon.

    curve[h] is the predicted *mean* power over [0, h], so the energy consumed
    by h is h/60 * curve[h]. That is monotone in h, so walk the grid and
    interpolate; past the last horizon extend at the final rate.
    """
    if energy_wh <= 0:
        return 0.0
    hs = sorted(curve)
    prev_h, prev_e = 0.0, 0.0
    for h in hs:
        p = max(curve[h], 0.05)
        e = h / 60.0 * p
        if e >= energy_wh:
            if e == prev_e:
                return h
            return prev_h + (h - prev_h) * (energy_wh - prev_e) / (e - prev_e)
        prev_h, prev_e = h, e
    tail = max(curve[hs[-1]], 0.05)
    return prev_h + (energy_wh - prev_e) / tail * 60.0


def solve_charge(model, soc, target_soc, e_full_wh, p_now):
    """Minutes to reach target_soc using the learned rate-vs-SOC curve."""
    if soc >= target_soc or e_full_wh <= 0:
        return 0.0
    minutes = 0.0
    s = soc
    step = 0.5
    while s < target_soc and minutes < 1440:
        b = int(s / 2)
        w = None
        for probe in (b, b - 1, b + 1, b - 2, b + 2):
            h = model.chg.get(str(probe))
            if h is not None and h.total() > 0.5:
                w = quantile(h.norm(), 0.5)
                break
        if w is None:
            w = p_now
        w = max(w, 0.5)
        de = step / 100.0 * e_full_wh
        minutes += de / w * 60.0
        s += step
    return minutes


def fmt_hm(minutes):
    if minutes is None or minutes < 0:
        return "--"
    minutes = int(round(minutes))
    if minutes >= 99 * 60:
        return "99h+"
    return "%dh%02d" % (minutes // 60, minutes % 60)


def fmt_h_short(minutes):
    """Compact single-unit form for the waybar bar text ('13h', '45m',
    '--'), as opposed to fmt_hm's 'HHhMM' used in the tooltip."""
    if minutes is None or minutes < 0:
        return "--"
    minutes = int(round(minutes))
    if minutes >= 99 * 60:
        return "99h+"
    if minutes < 60:
        return "%dm" % minutes
    return "%dh" % round(minutes / 60.0)


class Estimator:
    def __init__(self, model, sampler):
        self.m = model
        self.s = sampler
        self.ema = None
        self.last = None

    def update_ema(self, p, dt):
        if p is None:
            return
        if self.ema is None:
            self.ema = p
        else:
            a = 1 - math.exp(-dt / EMA_TAU_SEC)
            self.ema += a * (p - self.ema)

    def floor_wh(self, e_full_wh):
        """Energy that will never be usable, learned from how low the pack has
        actually gone while the machine was still running.

        Note most discharge runs end because the user plugged in, so their
        minima say nothing about the floor; only the deepest runs are
        informative. Hence the low order statistic rather than a percentile
        over all runs. The third-smallest (not the smallest) absorbs one
        anomalous reading, and the result is clamped so a machine that has
        never been run flat cannot produce an absurd floor either way.
        """
        vals = sorted(self.m.floor_wh)
        cap = 0.12 * e_full_wh
        if len(vals) >= 4:
            return max(0.0, min(vals[2], cap))
        return min(FLOOR_FRACTION_DEFAULT * e_full_wh, cap)

    def target_soc(self):
        tot = tgt = 0.0
        for b in self.s.bats:
            cf = rdi(os.path.join(b, "charge_full")) or 0
            end = rdi(os.path.join(b, "charge_control_end_threshold"), 100) or 100
            vn = self.s.vnom[b]
            tot += cf / 1e6 * vn
            tgt += cf / 1e6 * vn * end / 100.0
        return (100.0 * tgt / tot) if tot else 100.0

    def build(self, rec, recent_w):
        m = self.m
        p_now = max(self.ema or rec["p_batt_w"], 0.0) * m.calib
        e_full = rec["e_full_wh"]
        e_design = sum(self.s.design.values())
        out = {
            "ts": round(time.time(), 1),
            "soc": round(rec["soc"], 1),
            "e_wh": round(rec["e_wh"], 2),
            "e_full_wh": round(e_full, 2),
            "e_design_wh": round(e_design, 2),
            "health": round(100.0 * e_full / e_design, 1) if e_design else 0.0,
            "p_now_w": round(p_now, 2),
            "mode": rec.get("mode", "auto"),
            "top": classify(rec.get("top")),
            "days": round(m.minutes_seen / 1440.0, 2),
            "batt_hours": round(m.battery_minutes / 60.0, 1),
            "tau_min": round(m.tau, 1),
            "calib": round(m.calib, 4),
        }

        acc = m.acc
        n = sum(acc[h][0] for h in HORIZONS)
        if n > 50:
            mo = sum(acc[h][1] for h in HORIZONS) / n
            na = sum(acc[h][2] for h in HORIZONS) / n
            out["mae_w"] = round(mo, 2)
            out["naive_mae_w"] = round(na, 2)
            out["gain_pct"] = round(100.0 * (1 - mo / na), 1) if na > 0 else 0.0

        sus = [w for _, _, w in m.suspend[-20:] if w > 0]
        if sus:
            sus.sort()
            out["suspend_w"] = round(sus[len(sus) // 2], 2)

        target = self.target_soc()
        out["target_soc"] = round(target, 1)

        if rec["st"] == "C":
            out["state"] = "charging"
            p_chg = max(-rec["p_batt_w"], 0.1)
            out["p_chg_w"] = round(p_chg, 2)
            eta = solve_charge(m, rec["soc"], target, e_full, p_chg)
            out["eta_min"] = round(eta, 1)
            out["eta_lo_min"] = round(eta * 0.85, 1)
            out["eta_hi_min"] = round(eta * 1.2, 1)
            out["method"] = "curve" if m.chg else "instant"
            out["conf"] = "high" if len(m.chg) > 8 else "low"
        elif rec["ac"] and rec["st"] != "D":
            out["state"] = "ac"
            out["eta_min"] = -1
            out["method"] = "n/a"
            out["conf"] = "n/a"
        else:
            out["state"] = "discharging"
            keys = state_keys(rec, recent_w)
            mid, neff = m.forecast(keys, p_now, 0.5)
            hi, _ = m.forecast(keys, p_now, 0.9)
            lo, _ = m.forecast(keys, p_now, 0.1)
            usable = max(0.0, rec["e_wh"] - self.floor_wh(e_full))
            eta = solve_eta(mid, usable)
            out["eta_min"] = round(eta, 1)
            out["eta_lo_min"] = round(solve_eta(hi, usable), 1)
            out["eta_hi_min"] = round(solve_eta(lo, usable), 1)
            out["usable_wh"] = round(usable, 2)
            out["p_fore_w"] = round(usable / (eta / 60.0), 2) if eta > 1 else round(p_now, 2)
            out["p_1h_w"] = round(mid[60], 2)
            out["n_eff"] = round(neff, 1)
            out["method"] = "model" if neff > 0 else "instant"
            out["conf"] = ("high" if neff >= 12 else
                           "med" if neff >= 4 else
                           "low" if neff > 0 else "none")
            if eta > 0:
                out["eta_abs"] = time.strftime("%H:%M",
                                               time.localtime(time.time() + eta * 60))

        out["eta_hm"] = fmt_hm(out["eta_min"]) if out["eta_min"] >= 0 else "--"

        # Per-pack breakdown for the waybar "1:/2:" readout. self.s.bats is
        # sorted, so index 0 is always BAT0 (internal Li-poly) and index 1
        # BAT1 (removable Li-ion, Power Bridge) on this machine. Power Bridge
        # only ever moves one pack at a time, so only the pack whose own
        # sysfs status matches the system-wide state gets the shared eta;
        # the other one is idle and reports "--" rather than a stale number.
        # Fixed Power Bridge slots, read fresh here rather than via
        # self.s.bats: that list is fixed at daemon startup, and BAT1's
        # sysfs node disappears from /sys/class/power_supply entirely on a
        # hot-swap removal (it does not just flip present=0). Iterating the
        # two canonical paths and checking isdir() each call is what makes
        # a pulled/reinserted BAT1 show up correctly instead of silently
        # dropping (or never regaining) a slot for the rest of the process's
        # life.
        packs = []
        for b in ("/sys/class/power_supply/BAT0", "/sys/class/power_supply/BAT1"):
            if not os.path.isdir(b):
                packs.append({
                    "name": os.path.basename(b), "present": False,
                    "pct": 0.0, "wh": 0.0, "full_wh": 0.0, "status": "Absent",
                    "eta_min": -1, "eta_hm": "--",
                })
                continue
            cn = rdi(os.path.join(b, "charge_now"))
            cf = rdi(os.path.join(b, "charge_full"))
            vn = self.s.vnom.get(b)
            if vn is None:
                vn = (rdi(os.path.join(b, "voltage_min_design")) or
                      rdi(os.path.join(b, "voltage_now")) or 11400000) / 1e6
            if cn is not None and cf:
                wh, full_wh = cn / 1e6 * vn, cf / 1e6 * vn
            else:
                en = rdi(os.path.join(b, "energy_now")) or 0
                ef = rdi(os.path.join(b, "energy_full")) or 0
                wh, full_wh = en / 1e6, ef / 1e6
            pstatus = rd(os.path.join(b, "status")) or "Unknown"
            pct = round(100.0 * wh / full_wh, 1) if full_wh else 0.0
            active = ((pstatus == "Charging" and out["state"] == "charging") or
                      (pstatus == "Discharging" and out["state"] == "discharging"))
            packs.append({
                "name": os.path.basename(b),
                "present": True,
                "pct": pct,
                "wh": round(wh, 2),
                "full_wh": round(full_wh, 2),
                "status": pstatus,
                "eta_min": out["eta_min"] if active else -1,
                "eta_hm": out["eta_hm"] if active else "--",
            })
        out["packs"] = packs

        # BAT0 is TLP-managed to a strict 20-80% band (modules/power/tlp.nix).
        # Sitting at either rail means that threshold write didn't take (seen
        # once, 2026-09-25/26: tlp.service reported success but the sysfs
        # value stayed at the EC default) or the pack was cycled outside TLP;
        # either way it is calendar-ageing in the worst spot and worth a nag.
        bat0 = packs[0]
        bat0_pct = round(bat0["pct"])
        out["bat0_warn"] = bat0["present"] and (bat0_pct >= 100 or bat0_pct <= 0)
        return out


def waybar_payload(e):
    """Build the waybar JSON here rather than in the shell script, so the
    formatting and the pango escaping live next to the data that feeds them."""
    soc = e.get("soc", 0)
    state = e.get("state")
    eta = e.get("eta_hm", "--")
    packs = e.get("packs", [])
    warn = e.get("bat0_warn", False)

    if packs:
        # "BAT0 50% 13h BAT1 15% 1h": each pack gets its own %/eta segment,
        # labeled with its real device name (matches the tooltip and
        # `battery-model status` below, not a 1-indexed slot number).
        # The segment for whichever pack is actively discharging is colored
        # yellow so it's obvious at a glance which one is draining; BAT0
        # (internal) sitting outside its 20-80% band outranks that and shows
        # red instead, since that is a health warning, not just status.
        segs = []
        for i, p in enumerate(packs):
            if not p.get("present", True):
                # Same "BATn NN% Xh" shape as a present pack, placeholder
                # digits swapped for dashes, so pulling BAT1 doesn't reflow
                # the bar and shove everything to its right sideways.
                segs.append("BAT%d --%% --h" % i)
                continue
            eta_short = fmt_h_short(p.get("eta_min", -1))
            seg = "BAT%d %d%% %s" % (i, round(p["pct"]), eta_short)
            if i == 0 and warn:
                seg = "<span color='#B96B6B'>%s</span>" % seg
            elif p["status"] == "Discharging":
                seg = "<span color='#e5c07b'>%s</span>" % seg
            elif p["status"] == "Charging":
                seg = "<span color='#71A671'>%s</span>" % seg
            segs.append(seg)
        text = " ".join(segs)
    else:
        prefix = {"charging": "CHG", "ac": "PWR"}.get(state, "BAT")
        text = "%s %02d%% %s" % (prefix, soc, "--" if state == "ac" else eta)
        if state == "charging":
            text = "<span color='#71A671'>%s</span>" % text

    L = []
    if state == "discharging":
        L.append("%.1f%%  %.1f / %.1f Wh" % (soc, e.get("e_wh", 0), e.get("e_full_wh", 0)))
        L.append("%s remaining, empty around %s" % (eta, e.get("eta_abs", "?")))
        L.append("range %s to %s  (p10-p90)"
                 % (fmt_hm(e.get("eta_lo_min")), fmt_hm(e.get("eta_hi_min"))))
        L.append("")
        L.append("draw now      %.2f W" % e.get("p_now_w", 0))
        L.append("forecast      %.2f W mean, %.2f W next hour"
                 % (e.get("p_fore_w", 0), e.get("p_1h_w", 0)))
        L.append("usable        %.1f Wh above learned floor" % e.get("usable_wh", 0))
    elif state == "charging":
        L.append("%.1f%%  %.1f / %.1f Wh" % (soc, e.get("e_wh", 0), e.get("e_full_wh", 0)))
        L.append("%s to %.0f%% charge limit" % (eta, e.get("target_soc", 100)))
        L.append("")
        L.append("charging at   %.2f W" % e.get("p_chg_w", 0))
    else:
        L.append("%.1f%%  %.1f / %.1f Wh, on AC" % (soc, e.get("e_wh", 0), e.get("e_full_wh", 0)))
        L.append("charge limit  %.0f%%" % e.get("target_soc", 100))

    if packs:
        L.append("")
        for i, p in enumerate(packs):
            label = "BAT%d internal Li-poly" % i if i == 0 else "BAT%d removable Li-ion" % i
            if not p.get("present", True):
                L.append("%-22s absent (unplugged / hot-swapped out)" % label)
                continue
            L.append("%-22s %5.1f%%  %.1f/%.1f Wh  %s"
                     % (label, p["pct"], p["wh"], p["full_wh"], p["status"]))
            if p["eta_hm"] != "--":
                L.append("%-22s %s remaining" % ("", p["eta_hm"]))
        if warn:
            L.append("")
            L.append("! BAT0 (internal) is outside its 20-80% band -- check")
            L.append("  charge_control thresholds, this ages the pack fast")

    L.append("health        %.0f%% of design (%.0f Wh)"
             % (e.get("health", 0), e.get("e_design_wh", 0)))
    if "suspend_w" in e:
        L.append("suspended     %.2f W (%.1f%%/h)"
                 % (e["suspend_w"], 100.0 * e["suspend_w"] / max(e.get("e_full_wh", 1), 1)))
    L.append("")
    L.append("model         %s, %s confidence (n=%s)"
             % (e.get("method"), e.get("conf"), e.get("n_eff", "-")))
    L.append("regime        %s, cpu %s" % (e.get("top", "?"), e.get("mode", "?")))
    if "mae_w" in e:
        L.append("accuracy      %.2f W error, %.0f%% better than naive"
                 % (e["mae_w"], e.get("gain_pct", 0)))
    L.append("learned from  %.1f days (%.0f h on battery)"
             % (e.get("days", 0), e.get("batt_hours", 0)))

    tip = "\n".join(L)
    for a, b in (("&", "&amp;"), ("<", "&lt;"), (">", "&gt;")):
        tip = tip.replace(a, b)
    return {"text": text, "tooltip": tip,
            "class": state or "unknown",
            "percentage": int(soc)}


# ──────────────────────────────── the daemon ─────────────────────────────────


class Daemon:
    def __init__(self):
        self.logs = Logs()
        self.sampler = Sampler()
        self.model = self.load_model()
        self.trainer = Trainer(self.model)
        self.est = Estimator(self.model, self.sampler)
        self.minute_bucket = []
        self.minute_id = None
        self.running = True
        self.last_sample = None
        self.boot_offset = self.offset()
        self.calib_anchor = None
        self.recent_minutes = []
        signal.signal(signal.SIGTERM, self.stop)
        signal.signal(signal.SIGINT, self.stop)

    def stop(self, *_):
        self.running = False

    @staticmethod
    def offset():
        return time.clock_gettime(time.CLOCK_BOOTTIME) - time.monotonic()

    def load_model(self):
        path = os.path.join(STATE_DIR, "model.json")
        if os.path.exists(path):
            try:
                with open(path) as f:
                    m = Model.from_json(json.load(f))
                if m:
                    return m
            except (OSError, ValueError):
                pass
        sys.stderr.write("battery-model: rebuilding model from minutes.tsv\n")
        return rebuild_model()

    def save_model(self):
        self.model.updated = time.time()
        try:
            atomic_write(os.path.join(STATE_DIR, "model.json"),
                         json.dumps(self.model.to_json(), separators=(",", ":")))
        except OSError as e:
            sys.stderr.write("battery-model: model save failed: %s\n" % e)

    # -- suspend accounting --------------------------------------------------

    def check_suspend(self, s):
        off = self.offset()
        slept = off - self.boot_offset
        self.boot_offset = off
        if slept < 30 or not self.last_sample:
            return 0
        prev = self.last_sample
        de = prev["e_wh"] - s["e_wh"]
        hours = slept / 3600.0
        if de > 0 and hours > 0.02 and not prev["ac"] and not s["ac"]:
            watts = de / hours
            if 0 < watts < 15:
                self.model.suspend.append((round(time.time()), round(hours, 3),
                                           round(watts, 3)))
                self.model.suspend = self.model.suspend[-200:]
                try:
                    with open(os.path.join(STATE_DIR, "suspends.tsv"), "a") as f:
                        f.write("%d\t%.3f\t%.3f\t%.2f\t%.2f\n" %
                                (time.time(), hours, watts, prev["e_wh"], s["e_wh"]))
                except OSError:
                    pass
        return 1

    # -- current-sense calibration ------------------------------------------

    def calibrate(self, s):
        """current_now*voltage_now is an EC estimate; the honest number is the
        energy actually removed from the pack over a long window. Learn the
        ratio and apply it to every prediction."""
        if s["st"] != "D" or s["ac"]:
            self.calib_anchor = None
            return
        if self.calib_anchor is None:
            self.calib_anchor = (s["ts"], s["e_wh"], 0.0, 0)
            return
        t0, e0, psum, pn = self.calib_anchor
        psum += s["p_batt_w"]
        pn += 1
        self.calib_anchor = (t0, e0, psum, pn)
        dt = s["ts"] - t0
        if dt < 1800 or pn < 100:
            return
        de = e0 - s["e_wh"]
        p_mean = psum / pn
        if de > 0.3 and p_mean > 0.3:
            ratio = (de / (dt / 3600.0)) / p_mean
            if 0.75 < ratio < 1.35:
                m = self.model
                w = min(m.calib_n, 40.0)
                m.calib = (m.calib * w + ratio) / (w + 1)
                m.calib_n = w + 1
        self.calib_anchor = (s["ts"], s["e_wh"], 0.0, 0)

    # -- minute aggregation --------------------------------------------------

    def close_minute(self, gap):
        if not self.minute_bucket:
            return
        b = self.minute_bucket
        rec = {"ts": int(b[0]["ts"] // 60 * 60), "n": len(b), "gap": gap}
        for c in MEAN_COLS:
            if c in RAPL_SENTINEL_COLS:
                vals = [x[c] for x in b if isinstance(x.get(c), (int, float)) and x[c] >= 0]
            else:
                vals = [x[c] for x in b if isinstance(x.get(c), (int, float))]
            rec[c] = round(sum(vals) / len(vals), 3) if vals else 0.0
        for c in MODE_COLS:
            vals = [x.get(c) for x in b]
            rec[c] = max(set(vals), key=vals.count)
        # A minute that was on battery for any part of it is not a clean
        # battery minute; the trainer only accepts windows that are entirely D.
        if any(x["st"] != rec["st"] for x in b):
            rec["gap"] = 1
        self.logs.write_minute(rec)

        for c in MEAN_COLS + ("n", "gap"):
            rec[c] = float(rec[c])
        for c in ("scr", "ext", "wifi", "bt", "audio", "ac"):
            rec[c] = int(rec[c])
        rec["ts"] = float(rec["ts"])
        self.trainer.feed(rec)
        self.trainer.finish()
        self.recent_minutes.append(rec)
        if len(self.recent_minutes) > 30:
            self.recent_minutes.pop(0)
        self.minute_bucket = []

    def recent_power(self):
        vals = [r["p_batt_w"] for r in self.recent_minutes[-15:] if r["st"] == "D"]
        if not vals:
            return self.est.ema or 0.0
        return sum(vals) / len(vals)

    # -- main ----------------------------------------------------------------

    def tick(self, dt):
        now = time.time()
        s = self.sampler.sample(now, dt)
        s["gap"] = self.check_suspend(s)
        self.logs.write_raw(s)
        self.calibrate(s)

        if s["st"] == "D":
            self.est.update_ema(s["p_batt_w"], dt)
        elif s["st"] == "C":
            self.est.ema = None

        mid = int(s["ts"] // 60)
        if self.minute_id is None:
            self.minute_id = mid
        if mid != self.minute_id:
            self.close_minute(1 if s["gap"] else 0)
            self.minute_id = mid
        self.minute_bucket.append(s)
        self.last_sample = s

        live = dict(s)
        if self.recent_minutes:
            live.setdefault("mode", self.recent_minutes[-1].get("mode"))
        est = self.est.build(live, self.recent_power())
        atomic_write(os.path.join(STATE_DIR, "estimate.json"),
                     json.dumps(est, separators=(",", ":")))
        atomic_write(os.path.join(STATE_DIR, "estimate.kv"),
                     "".join("%s=%s\n" % (k, v) for k, v in sorted(est.items())))
        atomic_write(os.path.join(STATE_DIR, "waybar.json"),
                     json.dumps(waybar_payload(est), separators=(",", ":")))

    def run(self):
        next_tick = time.monotonic()
        last_save = time.monotonic()
        last = time.time()
        while self.running:
            now = time.time()
            dt = max(0.5, min(now - last, 120.0))
            last = now
            try:
                self.tick(dt)
            except Exception as e:                      # never die on one bad read
                sys.stderr.write("battery-model: tick failed: %r\n" % (e,))
            if time.monotonic() - last_save > 300:
                self.save_model()
                self.logs.flush()
                last_save = time.monotonic()
            next_tick += SAMPLE_SEC
            sleep = next_tick - time.monotonic()
            if sleep < -SAMPLE_SEC:                     # resumed from suspend
                next_tick = time.monotonic() + SAMPLE_SEC
                sleep = SAMPLE_SEC
            time.sleep(max(sleep, 0.05))
        self.close_minute(0)
        self.save_model()
        self.logs.flush()


def rebuild_model(evaluate=True, verbose=False):
    m = Model()
    t = Trainer(m, evaluate=evaluate)
    n = 0
    start = time.time()
    for rec in read_minutes():
        t.feed(rec)
        n += 1
    t.finish()
    if verbose:
        sys.stderr.write("battery-model: replayed %d minutes in %.1fs\n"
                         % (n, time.time() - start))
    return m


# ──────────────────────────────────── CLI ────────────────────────────────────


def cmd_status():
    path = os.path.join(STATE_DIR, "estimate.json")
    if not os.path.exists(path):
        print("no estimate yet (is battery-model.service running?)")
        return 1
    with open(path) as f:
        e = json.load(f)
    age = time.time() - e.get("ts", 0)
    print("state      %s  (%.0fs old)" % (e.get("state"), age))
    print("charge     %.1f%%  %.2f/%.2f Wh   health %.1f%% of design"
          % (e.get("soc", 0), e.get("e_wh", 0), e.get("e_full_wh", 0), e.get("health", 0)))
    for i, p in enumerate(e.get("packs", [])):
        warn = " [!! outside 20-80% band]" if (i == 0 and e.get("bat0_warn")) else ""
        print("  BAT%d     %5.1f%%  %.2f/%.2f Wh  %-12s%s%s"
              % (i, p["pct"], p["wh"], p["full_wh"], p["status"],
                 ("  " + p["eta_hm"] if p["eta_hm"] != "--" else ""), warn))
    if e.get("state") == "discharging":
        print("draw       %.2f W now, %.2f W forecast mean, %.2f W next hour"
              % (e.get("p_now_w", 0), e.get("p_fore_w", 0), e.get("p_1h_w", 0)))
        print("remaining  %s   (range %s - %s)  empty at %s"
              % (e.get("eta_hm"), fmt_hm(e.get("eta_lo_min")),
                 fmt_hm(e.get("eta_hi_min")), e.get("eta_abs", "?")))
        print("usable     %.2f Wh above the learned floor" % e.get("usable_wh", 0))
    elif e.get("state") == "charging":
        print("charging   %.2f W, full (%.0f%%) in %s"
              % (e.get("p_chg_w", 0), e.get("target_soc", 100), e.get("eta_hm")))
    print("model      %s / %s, n_eff %s, regime %s, mode %s"
          % (e.get("method"), e.get("conf"), e.get("n_eff", "-"),
             e.get("top"), e.get("mode")))
    print("history    %.2f days logged, %.1f h on battery, tau %.0f min, calib %.3f"
          % (e.get("days", 0), e.get("batt_hours", 0), e.get("tau_min", 0),
             e.get("calib", 1)))
    if "mae_w" in e:
        print("accuracy   %.2f W MAE vs %.2f W naive  (%.0f%% better)"
              % (e["mae_w"], e["naive_mae_w"], e.get("gain_pct", 0)))
    if "suspend_w" in e:
        print("suspend    %.2f W in S3 (%.1f%%/h)"
              % (e["suspend_w"], 100.0 * e["suspend_w"] / max(e.get("e_full_wh", 1), 1)))
    return 0


def cmd_report():
    m = rebuild_model(evaluate=True, verbose=True)
    print("minutes logged     %d (%.2f days), on battery %d (%.1f h)"
          % (m.minutes_seen, m.minutes_seen / 1440.0, m.battery_minutes,
             m.battery_minutes / 60.0))
    print("regime e-fold tau  %.0f min" % m.tau)
    print("states learned     %d keys, %d charge buckets" % (len(m.fwd), len(m.chg)))
    n = sum(m.acc[h][0] for h in HORIZONS)
    if n:
        print("\nforecast accuracy (mean abs error of predicted mean power):")
        print("  horizon   n      model    persistence   gain")
        for h in HORIZONS:
            c, mo, na = m.acc[h]
            if c:
                print("  %4d min  %-6d %6.2f W   %6.2f W   %+5.1f%%"
                      % (h, c, mo / c, na / c,
                         100.0 * (1 - (mo / c) / (na / c)) if na else 0))
    print("\ntypical draw by screen state and power band (median W over 60 min):")
    rows = []
    for key, d in m.fwd.items():
        if not key.startswith("*|") or key.count("|") != 2 or 60 not in d:
            continue
        h = d[60]
        if h.total() < 2:
            continue
        rows.append((key, h.total(), quantile(h.norm(), 0.1),
                     quantile(h.norm(), 0.5), quantile(h.norm(), 0.9)))
    for key, tot, p10, p50, p90 in sorted(rows, key=lambda r: -r[1])[:14]:
        scr = {"0": "blank", "1": "internal", "2": "external",
               "*": "any"}.get(key.split("|")[1], "?")
        print("  %-9s band %-2s  n=%-6.1f  p10 %5.2f  p50 %5.2f  p90 %5.2f"
              % (scr, key.split("|")[2], tot, p10, p50, p90))
    if m.chg:
        print("\ncharge power by state of charge:")
        for b in sorted(m.chg, key=lambda x: int(x)):
            h = m.chg[b]
            if h.total() >= 1:
                print("  %3d-%3d%%  n=%-6.1f  %5.2f W"
                      % (int(b) * 2, int(b) * 2 + 2, h.total(), quantile(h.norm(), 0.5)))
    if m.suspend:
        w = sorted(x[2] for x in m.suspend)
        print("\nS3 suspend drain   median %.2f W over %d sleeps"
              % (w[len(w) // 2], len(w)))
    if m.floor_wh:
        f = sorted(m.floor_wh)
        # Mirror Estimator.floor_wh() exactly (3rd-smallest run once >=4
        # exist) rather than a percentile index, so this line reports what
        # the live estimator actually uses instead of a different number.
        idx = 2 if len(f) >= 4 else 0
        print("learned empty floor %.2f Wh (from %d runs)" % (f[idx], len(f)))
    return 0


def cmd_rebuild():
    m = rebuild_model(evaluate=True, verbose=True)
    m.updated = time.time()
    atomic_write(os.path.join(STATE_DIR, "model.json"),
                 json.dumps(m.to_json(), separators=(",", ":")))
    print("wrote model.json (%d keys)" % len(m.fwd))
    return 0


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "daemon"
    if cmd == "daemon":
        os.makedirs(STATE_DIR, exist_ok=True)
        try:
            os.chmod(STATE_DIR, 0o755)
        except OSError:
            pass
        Daemon().run()
        return 0
    if cmd == "status":
        return cmd_status()
    if cmd == "report":
        return cmd_report()
    if cmd == "rebuild":
        return cmd_rebuild()
    sys.stderr.write(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
