{
  # Bluetooth is enabled but off-at-boot. The waybar "custom/bluetooth" toggle
  # (bt_toggle.sh) flips it: on = rfkill unblock + bluetoothctl power on; off =
  # bluetoothctl power off + rfkill block bluetooth (kernel radio cut, nothing
  # can scan or advertise). USBGuard permits the internal AX210 BT radio
  # (8087:0032) so btusb can bind; see hardening-physical.
  nixos.modules.bluetooth = {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = false;
    };
    services.blueman.enable = true;

    # The ThinkPad EC exposes bluetooth as an ACPI kill switch at
    # /proc/acpi/ibm/bluetooth. On T480/Libreboot it boots "disabled", which
    # physically disconnects the AX210 BT radio from the USB bus (so btusb
    # cannot bind and no hci0 exists). Force-enable at boot; the waybar toggle
    # then controls the softer rfkill + adapter-power state on top.
    system.activationScripts.thinkpadAcpiBluetoothEnable.text = ''
      if [ -w /proc/acpi/ibm/bluetooth ]; then
        echo enable > /proc/acpi/ibm/bluetooth || true
      fi
    '';
  };
}
