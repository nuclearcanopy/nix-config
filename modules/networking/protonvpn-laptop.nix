{
  # Proton VPN user-session integration for Nidhoggr. The official CLI keeps
  # credentials in the user's session and only supports its standard kill switch
  # (active-tunnel leak protection, not Mullvad-style permanent lockdown).
  homeManager.modules.protonvpn-laptop = { pkgs, ... }: {
    home.packages = [ pkgs.proton-vpn-cli ];

    systemd.user.services.protonvpn-autoconnect = {
      Unit = {
        Description = "Connect Proton VPN for the Sway session";
        PartOf = [ "sway-session.target" ];
        After = [ "sway-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "protonvpn-autoconnect" ''
          set -eu
          ${pkgs.networkmanager}/bin/nm-online -s -q -t 30 || true
          ${pkgs.proton-vpn-cli}/bin/protonvpn config set kill-switch standard
          exec ${pkgs.proton-vpn-cli}/bin/protonvpn connect
        '';
        TimeoutStartSec = 180;
      };
      Install.WantedBy = [ "sway-session.target" ];
    };
  };
}
