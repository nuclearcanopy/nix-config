{ ... }:

{
  # connectivity checks
  networking.networkmanager.settings = {
    connectivity = {
      enabled = false;
      uri = "";
    };
  };

  # location services
  services.geoclue2.enable = false;

  # gnome telemetry
  services.gnome.gnome-keyring.enable = false;
  services.gnome.tinysparql.enable = false;
  services.gnome.localsearch.enable = false;

  # packagekit
  services.packagekit.enable = false;
}
