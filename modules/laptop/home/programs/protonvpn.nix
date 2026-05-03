{ lib, ... }:

{
  # Declarative ProtonVPN app config.
  # connect_at_app_startup: server name or "FASTEST"; null = don't autoconnect.
  # NOTE: this file is managed by Nix — in-app changes will be overwritten on rebuild.
  home.file.".config/Proton/VPN/app-config.json".text = builtins.toJSON {
    tray_pinned_servers = [];
    connect_at_app_startup = "FASTEST";
    start_app_minimized = true;
  };
}
