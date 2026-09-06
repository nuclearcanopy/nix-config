{
  # Laptop-only hardening on top of the shared hardening bucket.
  # Threat model: physical attacker with brief unsupervised access (evil-maid,
  # bag snatcher), untrusted USB/TB peripherals at conferences/cafes/borders.
  # JOP/ROP defense is software-only here; the i5-8350U predates Intel CET
  # (Tiger Lake/11th gen), so hardware Shadow Stack and IBT are unavailable.
  # Compensated with stack randomization, lockdown, reduced attack surface.
  nixos.modules.hardening-physical = { pkgs, username, ... }: {
    boot = {
      kernelParams = [
        # DMA protection. VT-d works under Libreboot (ME is neutered, not
        # removed). iommu.strict=1 forces synchronous IOTLB invalidation;
        # closes the window where a freed DMA region is still mapped.
        # passthrough=0: every device goes through the IOMMU (no fast-path
        # bypass for "trusted" devices when "trusted" can't be assumed).
        "intel_iommu=on"
        "iommu=force"
        "iommu.strict=1"
        "iommu.passthrough=0"
        # No-op under Libreboot (no UEFI) but harmless if EFI fallback is taken.
        "efi=disable_early_pci_dma"

        # NOTE: `lockdown=confidentiality` was removed 2026-08-22. It was a no-op:
        # the stock kernel compiles the lockdown LSM but does not stack it unless
        # named in `lsm=`, so the param was silently ignored (LSM list was
        # capability,landlock,yama,apparmor,bpf,ima; /sys/kernel/security/lockdown
        # absent). Enabling it for real (`lsm=...,lockdown,...`) would block MSR
        # writes and kill the undervolt service, which we keep. Left off deliberately.
      ];

      # Thunderbolt: PCIe-tunneled-over-USB-C is the dominant DMA attack
      # surface. With the driver blacklisted the kernel never exposes the TB
      # controller's PCIe tunnel, so a malicious TB device cannot establish
      # a DMA channel. The USB-C port itself keeps working for:
      #   - PD charging (handled by the EC, not the kernel)
      #   - plain USB devices like YubiKey (USB-C → xHCI mux, independent
      #     of the thunderbolt driver)
      # What's lost: TB3 docks, TB displays, eGPUs. Acceptable trade.
      # firewire-* defensively blacklisted even though T480 has no FW port.
      # btusb/bluetooth intentionally NOT blacklisted: bluetooth is enabled with
      # powerOnBoot=false and toggled via the waybar bt button (rfkill block +
      # bluetoothctl power off on the off state).
      blacklistedKernelModules = [ "thunderbolt" "firewire-core" "firewire-ohci" "firewire-sbp2" ];
    };

    # With the thunderbolt driver blacklisted the TB PCIe devices (Alpine
    # Ridge NHI at 04:00.0 and TB USB controller at 06:00.0) have no driver
    # to manage their runtime PM. The kernel still puts them into D3cold via
    # PCI PM, but without the driver they can't return to D0, and any probe
    # from userspace (libvirtd's PCI enumerator, lspci) sees garbage config
    # space and reports errors like `PCI header type 127` or
    # `xhci_hcd: HC died`. Pin them to D0 so probes read valid state.
    services.udev.extraRules = ''
      SUBSYSTEM=="pci", KERNEL=="0000:04:00.0", ATTR{power/control}="on"
      SUBSYSTEM=="pci", KERNEL=="0000:06:00.0", ATTR{power/control}="on"
    '';

    # MAC framework: confines browsers and other high-risk userspace processes.
    # killUnconfinedConfinables=true: if a binary has a profile but starts
    # before AppArmor loads, kill it rather than let it run unconfined.
    security.apparmor = {
      enable = true;
      killUnconfinedConfinables = true;
      packages = [ pkgs.apparmor-profiles ];
    };

    # USBGuard: block-by-default for newly inserted USB devices. Devices
    # plugged in at daemon start are allowed (presentDevicePolicy=allow), so
    # the internal webcam, card reader, fingerprint reader, and any mouse
    # plugged in at boot all work without listing.
    # The allowlist for new inserts is declared here in services.usbguard.rules;
    # nix-store-managed (immutable, reinstall-safe) and disables the IPC-driven
    # `usbguard allow-device -p` workflow. To trust a new device:
    #   sudo usbguard list-devices  # find vid:pid
    #   add `allow id <vid>:<pid>` here and rebuild.
    services.usbguard = {
      enable = true;
      IPCAllowedUsers = [ username "root" ];
      rules = ''
        # Yubico security keys: all models (FIDO, OTP, CCID, 5-series).
        # Vendor-wide so spare/replacement keys work without a rebuild.
        allow id 1050:*
        # Logitech Unifying / Bolt USB receiver (mouse + keyboard HID).
        allow id 046d:c547
        # PFU Happy Hacking Keyboard Professional HYBRID Type-S.
        allow id 04fe:0021
        # Apple iPhone (5/SE/6/7/8/X/XR family PID, for USB tethering via usbmuxd).
        allow id 05ac:12a8
        # Intel AX210 Bluetooth (integrated with the Wi-Fi 6E card). Needed so
        # btusb can bind when the waybar bt toggle powers the radio on.
        allow id 8087:0032
        # Huawei USB-C audio dongle (USB-Audio class).
        allow id 12d1:3a06
        # FiiO KA11 USB-C DAC/headphone amp.
        allow id 2972:0081
      '';
      implicitPolicyTarget = "block";
      presentDevicePolicy = "allow";        # devices at daemon start: trust
      presentControllerPolicy = "allow";    # internal xHCI controllers: trust
      insertedDevicePolicy = "apply-policy"; # new inserts: consult rules above
      dbus.enable = true;
    };

    # Desktop notification whenever USBGuard blocks a newly inserted device,
    # so a rejected stick is visible instead of silently doing nothing. Reaches
    # the daemon over IPC, which works unprivileged because the user is in
    # IPCAllowedUsers above; mako renders the notification.
    #
    # To then allow the device, use the Mod+Shift+U picker bound in the
    # nidhoggr block of modules/gui/sway-host.nix.
    # That allow lasts until reboot: the ruleset is nix-store immutable, so a
    # device you want permanently must get an `allow id <vid>:<pid>` line in
    # the rules above followed by a rebuild.
    systemd.user.services.usbguard-notifier = {
      description = "USBGuard block notifications";
      after = [ "usbguard.service" ];
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.usbguard-notifier}/bin/usbguard-notifier";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    environment.systemPackages = with pkgs; [
      usbguard          # CLI for list-devices (finding vid:pid to declare)
      usbguard-notifier
    ];
  };
}
