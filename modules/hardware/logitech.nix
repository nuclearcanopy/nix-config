{
  # Battery readout for the G502 X Lightspeed via its receiver (046d:c547).
  #
  # The kernel cannot do this. `hid-logitech-dj` and `hid-logitech-hidpp` both
  # bind by explicit HID id table and neither lists c547 (dj tops out at c543
  # in the lightspeed/nano range), so the receiver falls through to
  # `hid-generic`, no HID++ transport is set up, and no
  # /sys/class/power_supply/hidpp_battery_0 node is ever created. That sysfs
  # node is what waybar's mouse_battery.sh reads; without it the module can
  # only print "MSE --%".
  #
  # solaar speaks HID++ from userspace over /dev/hidraw*, and does know this
  # receiver (logitech_receiver/base_usb.py: LIGHTSPEED_RECEIVER_C547).
  # logitech-udev-rules tags 046d hidraw nodes with uaccess, which hands the
  # seated user an ACL on them; they are root-only 0600 otherwise.
  #
  # Only the udev rules are taken from upstream's hardware.logitech.wireless,
  # not the option itself: it also drags in ltunify, which cannot talk to this
  # receiver either (it is Unifying-only).
  nixos.modules.logitech = { pkgs, ... }: {
    services.udev.packages = [ pkgs.logitech-udev-rules ];

    # Kept next to the rules deliberately: the rules exist only to let this
    # binary work, and the binary is useless without them.
    environment.systemPackages = [ pkgs.solaar ];
  };
}
