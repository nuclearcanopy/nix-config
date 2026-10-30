{
  # System-side sway enablement. The user-side sway config lives in the
  # sway-base bucket (homeManager).
  nixos.modules.sway-system = { pkgs, ... }: {
    programs.sway = {
      enable = true;
      wrapperFeatures.gtk = true;
      xwayland.enable = true;

      # Pinned because this list lands in environment.systemPackages
      # wholesale, and the nixpkgs default also drags in foot, wmenu and
      # pulseaudio. foot and wmenu are referenced nowhere (the terminal is
      # ghostty, the launcher is j4-dmenu-desktop + bemenu); pulseaudio is
      # used, for pactl, but gui-packages.nix now names it directly instead
      # of relying on this leak.
      extraPackages = with pkgs; [
        brightnessctl
        grim
        swayidle
        swaylock
      ];
    };

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };
  };
}
