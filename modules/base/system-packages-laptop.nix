{
  # Laptop-specific system packages: mullvad CLI, brightness control,
  # NM applet, battery info, password generator, internal firmware flasher.
  nixos.modules.system-packages-laptop = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      mullvad-vpn

      brightnessctl
      networkmanagerapplet
      acpi
      linuxPackages.turbostat

      xkcdpass

      flashprog  # internal firmware flashing (Libreboot updates)
    ];
  };
}
