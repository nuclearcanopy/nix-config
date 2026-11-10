{
  # Laptop-specific system packages: Proton VPN CLI, brightness control,
  # NM applet, battery info, password generator, internal firmware flasher.
  nixos.modules.system-packages-laptop = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      proton-vpn-cli

      brightnessctl
      networkmanagerapplet
      acpi
      linuxPackages.turbostat

      xkcdpass

      flashprog  # internal firmware flashing (Libreboot updates)
    ];
  };
}
