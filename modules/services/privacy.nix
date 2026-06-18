{
  # Privacy / telemetry kills: disable NM connectivity-check, geoclue, gnome
  # crawlers, packagekit; keep gnome-keyring for secrets storage.
  nixos.modules.privacy = {
    networking.networkmanager.settings = {
      connectivity = {
        enabled = false;
        uri = "";
      };
    };

    services.geoclue2.enable = false;

    services.gnome.gnome-keyring.enable = true;
    services.gnome.tinysparql.enable = false;
    services.gnome.localsearch.enable = false;

    services.packagekit.enable = false;
  };
}
