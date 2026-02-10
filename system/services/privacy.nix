{ ... }:

{
  # connectivity
  networking.networkmanager.settings = {
    connectivity = {
      enabled = false;
      uri = "";
    };
  };

  # location
  services.geoclue2.enable = false;

  # gnome
  services.gnome.gnome-keyring.enable = true; # protonvpn & element require it
  services.gnome.tinysparql.enable = false;
  services.gnome.localsearch.enable = false;

  # packagekit
  services.packagekit.enable = false;
}
