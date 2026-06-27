{
  # evdev-level caps->ctrl + lalt/lctl swap on the T480 internal keyboard.
  # Mirrors the sway xkb_options (ctrl:nocaps,ctrl:swap_lalt_lctl) so games
  # like Minecraft that read raw key codes via XWayland/LWJGL also see Ctrl.
  # Scoped by vendor:product id so the HHKB and external keyboards are
  # untouched.
  nixos.modules.keyd-internal-kbd = {
    services.keyd = {
      enable = true;
      keyboards.internal = {
        ids = [ "0001:0001" ];
        settings.main = {
          capslock = "leftcontrol";
          leftalt = "leftcontrol";
          leftcontrol = "leftalt";
        };
      };
    };
  };
}
