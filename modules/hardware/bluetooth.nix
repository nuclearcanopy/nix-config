{
  # Bluetooth is enabled but off-at-boot. The waybar "custom/bluetooth" toggle
  # (bt_toggle.sh) flips it: on = rfkill unblock + bluetoothctl power on; off =
  # bluetoothctl power off + rfkill block bluetooth (kernel radio cut, nothing
  # can scan or advertise). USBGuard permits the internal AX210 BT radio
  # (8087:0032) so btusb can bind; see hardening-physical.
  nixos.modules.bluetooth = { pkgs, ... }: {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = false;
    };
    services.blueman.enable = true;

    # The ThinkPad EC exposes bluetooth as an ACPI kill switch at
    # /proc/acpi/ibm/bluetooth. On T480/Libreboot it boots "disabled", which
    # physically disconnects the AX210 BT radio from the USB bus (so btusb
    # cannot bind and no hci0 exists). Clear it so the waybar toggle has a
    # softer rfkill + adapter-power state to control on top.
    #
    # This has to be udev, not an activation script. thinkpad_acpi is probed
    # from ACPI well after activation (2.57s after it on 2026-10-30:
    # activation finished 20:14:30.02, module loaded 20:14:32.59), so the proc
    # file did not exist yet, the old `[ -w ... ]` guard silently skipped, and
    # bluetooth was dead on every boot: no hci0, so bt_mode.sh's /^hci/ match
    # never fired and the toggle could not clear an ACPI-level hard block.
    # It only ever looked correct during an interactive nixos-rebuild switch,
    # where the module is already loaded. Keying on the rfkill device rather
    # than the platform device guarantees thinkpad_acpi finished registering.
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="rfkill", ATTR{name}=="tpacpi_bluetooth_sw", RUN+="${pkgs.bash}/bin/sh -c 'echo enable > /proc/acpi/ibm/bluetooth'"
    '';

    # Covers the already-loaded case (rebuild-switch on a running system),
    # where no rfkill add event fires. Harmless no-op at boot.
    system.activationScripts.thinkpadAcpiBluetoothEnable.text = ''
      if [ -w /proc/acpi/ibm/bluetooth ]; then
        echo enable > /proc/acpi/ibm/bluetooth || true
      fi
    '';
  };
}
