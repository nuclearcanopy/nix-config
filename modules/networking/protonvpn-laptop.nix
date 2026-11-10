{
  # Proton VPN GUI integration for Nidhoggr. The GUI supports FIDO2 sign-in and
  # its Advanced kill switch; login, kill switch, and auto-connect preferences
  # are configured in the app and persist in the user's home directory.
  homeManager.modules.protonvpn-laptop = { pkgs, ... }: {
    home.packages = [ pkgs.proton-vpn ];

    systemd.user.services.protonvpn-gui = {
      Unit = {
        Description = "Start Proton VPN GUI for the Sway session";
        PartOf = [ "sway-session.target" ];
        After = [ "sway-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.proton-vpn}/bin/protonvpn-app";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install.WantedBy = [ "sway-session.target" ];
    };
  };
}
