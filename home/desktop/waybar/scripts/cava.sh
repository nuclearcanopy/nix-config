#!/usr/bin/env bash
set -u

trap '' PIPE

config_file="/tmp/waybar_cava_config"

cat >"$config_file" <<'EOF'
[general]
bars = 12
framerate = 30

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
EOF

awk_prog='{
  gsub(/;/,"");
  gsub(/0/,"▁"); gsub(/1/,"▂"); gsub(/2/,"▃"); gsub(/3/,"▄");
  gsub(/4/,"▅"); gsub(/5/,"▆"); gsub(/6/,"▇"); gsub(/7/,"█");
  print;
  fflush();
}'

viz_pgid=""

start_viz() {
  if [[ -n "$viz_pgid" ]] && kill -0 "$viz_pgid" 2>/dev/null; then
    return
  fi
  # New process group so we can kill the whole pipeline cleanly
  setsid bash -c "exec cava -p '$config_file' 2>/dev/null | awk '$awk_prog'" &
  viz_pgid=$!
}

stop_viz() {
  if [[ -n "$viz_pgid" ]] && kill -0 "$viz_pgid" 2>/dev/null; then
    kill -TERM -"$viz_pgid" 2>/dev/null
    wait "$viz_pgid" 2>/dev/null
  fi
  viz_pgid=""
  printf '\n'
}

trap 'stop_viz; rm -f "$config_file"' EXIT

# Prime with current status, then follow changes
current="$(playerctl --player=Feishin status 2>/dev/null || true)"
if [[ "$current" == "Playing" ]]; then
  start_viz
else
  stop_viz
fi

playerctl --player=Feishin --follow status 2>/dev/null | while IFS= read -r st; do
  if [[ "$st" == "Playing" ]]; then
    start_viz
  else
    stop_viz
  fi
done


