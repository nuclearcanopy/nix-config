{ ... }:

{
  networking.networkmanager.settings = {
    connectivity = {
      enabled = false;
      uri = "";
    };
  };

  services.geoclue2.enable = false;

  services.gnome.gnome-keyring.enable = false;
  services.gnome.tinysparql.enable = false;
  services.gnome.localsearch.enable = false;

  services.packagekit.enable = false;
}
