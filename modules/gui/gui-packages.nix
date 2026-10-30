{
  homeManager.modules.gui-packages = { pkgs, ... }: {
    home.packages = with pkgs; [
      yubikey-manager
      bemenu
      j4-dmenu-desktop
      pavucontrol
      mpv
      playerctl
      grim
      slurp
      hyprpicker
      wl-clipboard
      jp2a
      autotiling-rs
      # notify-send, called by the usbguard allow/popup scripts and
      # set-theme-mode. Nothing installed it before, so every one of those
      # notifications was silently swallowed by its own `|| true`.
      libnotify
      # pactl, for the `pactl subscribe` event loops in waybar's volume.sh
      # and mic.sh. It only ever reached PATH as a side effect of sway's
      # default extraPackages, which sway-system.nix now pins; the scripts
      # swallow its absence silently, so name the dependency here.
      pulseaudio
    ];
  };
}
