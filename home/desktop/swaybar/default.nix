{ pkgs, ... }:

let
  # custom scripts for swaybar blocks
  lactScript = pkgs.writeShellScript "lact-status" ''
    profile=$(lact cli profile get 2>/dev/null || echo "?")
    echo "{\"text\":\"GPU $profile\",\"state\":\"Idle\"}"
  '';

  lactClickScript = pkgs.writeShellScript "lact-click" ''
    current=$(lact cli profile get 2>/dev/null)
    case "$current" in
      LOW) lact cli profile set MID ;;
      MID) lact cli profile set MAX ;;
      MAX) lact cli profile set LOW ;;
      *) lact cli profile set LOW ;;
    esac
  '';

  gpuUsageScript = pkgs.writeShellScript "gpu-usage" ''
    usage=$(cat /sys/class/hwmon/hwmon5/device/gpu_busy_percent 2>/dev/null || echo "?")
    temp=$(cat /sys/class/hwmon/hwmon5/temp2_input 2>/dev/null || echo "0")
    temp_c=$((temp / 1000))
    echo "{\"text\":\"''${temp_c}° ''${usage}%\",\"state\":\"Idle\"}"
  '';

  micStatusScript = pkgs.writeShellScript "mic-status" ''
    muted=$(pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null | grep -q "yes" && echo "yes" || echo "no")
    if [ "$muted" = "yes" ]; then
      echo "{\"text\":\"MIC MUTE\",\"state\":\"Warning\"}"
    else
      echo "{\"text\":\"MIC\",\"state\":\"Idle\"}"
    fi
  '';

  powerScript = pkgs.writeShellScript "power-click" ''
    systemctl suspend
  '';

  rebootScript = pkgs.writeShellScript "reboot-click" ''
    systemctl reboot
  '';

  i3statusConfig = pkgs.writeText "i3status-rs-config.toml" ''
    [icons]
    icons = "none"

    [theme]
    theme = "plain"
    [theme.overrides]
    idle_bg = "#060606"
    idle_fg = "#a0a0a0"
    info_bg = "#060606"
    info_fg = "#a0a0a0"
    good_bg = "#060606"
    good_fg = "#a0a0a0"
    warning_bg = "#060606"
    warning_fg = "#B96B6B"
    critical_bg = "#060606"
    critical_fg = "#B96B6B"
    separator_bg = "#060606"
    separator_fg = "#060606"
    separator = ""

    # clock
    [[block]]
    block = "time"
    interval = 60
    format = " ''$timestamp.datetime(f:'%d.%m %a %H:%M') "

    # volume
    [[block]]
    block = "sound"
    format = " VOL ''$volume "
    format_muted = " VOL MUTE "
    show_volume_when_muted = false
    [[block.click]]
    button = "left"
    cmd = "pactl -- set-sink-mute @DEFAULT_SINK@ toggle"
    [[block.click]]
    button = "middle"
    cmd = "pavucontrol"

    # mic status
    [[block]]
    block = "custom"
    command = "${micStatusScript}"
    json = true
    interval = 2
    [[block.click]]
    button = "left"
    cmd = "pactl set-source-mute @DEFAULT_SOURCE@ toggle"

    # mpris
    [[block]]
    block = "music"
    format = " [''$play''$artist] "
    player = "spotify"
    interface_name_exclude = ["firefox", "librewolf"]
    [block.theme_overrides]
    idle_fg = "#666666"

    # separator for center alignment simulation
    [[block]]
    block = "custom"
    command = "echo ' '"
    interval = "once"

    # memory
    [[block]]
    block = "memory"
    format = " MEM ''$mem_used.eng(prefix:G, w:3, p:1) "
    interval = 5

    # cpu temp + usage
    [[block]]
    block = "cpu"
    format = " CPU ''$utilization "
    interval = 2

    [[block]]
    block = "temperature"
    format = " ''$average° "
    chip = "*-isa-*"
    interval = 5

    # gpu profile (LACT)
    [[block]]
    block = "custom"
    command = "${lactScript}"
    json = true
    interval = 30
    [[block.click]]
    button = "left"
    cmd = "${lactClickScript}"

    # gpu temp + usage
    [[block]]
    block = "custom"
    command = "${gpuUsageScript}"
    json = true
    interval = 5

    # reboot
    [[block]]
    block = "custom"
    command = "echo '{\"text\":\"RBT\",\"state\":\"Idle\"}'"
    json = true
    interval = "once"
    [[block.click]]
    button = "middle"
    cmd = "${rebootScript}"

    # power
    [[block]]
    block = "custom"
    command = "echo '{\"text\":\"PWR\",\"state\":\"Idle\"}'"
    json = true
    interval = "once"
    [[block.click]]
    button = "middle"
    cmd = "${powerScript}"
  '';
in
{
  home.packages = [ pkgs.i3status-rust ];

  # swaybar is configured directly in sway config
  # this module just provides the i3status-rust config
  xdg.configFile."i3status-rust/config.toml".source = i3statusConfig;
}
