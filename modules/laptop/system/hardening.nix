{ pkgs, username, ... }:

# Laptop-only hardening for nidhoggr (T480, i5-8350U).
# Threat model: physical attacker with brief unsupervised access (evil-maid,
# bag snatcher), and untrusted USB/Thunderbolt peripherals at conferences /
# cafés / borders. JOP/ROP defense is software-only here — the i5-8350U
# predates Intel CET (Tiger Lake/11th gen), so hardware Shadow Stack and
# Indirect Branch Tracking are unavailable. We compensate with stack
# randomization, lockdown, and reduced attack surface.
{
  boot = {
    kernelParams = [
      # ── DMA protection ────────────────────────────────────────────────────
      # VT-d still works under Libreboot (the ME is neutered, not removed).
      # iommu.strict=1 forces synchronous IOTLB invalidation — closes the
      # window where a freed DMA region is still mapped. passthrough=0 means
      # every device goes through the IOMMU (no fast-path bypass for trusted
      # devices, which is what we want when "trusted" can't be assumed).
      "intel_iommu=on"
      "iommu=force"
      "iommu.strict=1"
      "iommu.passthrough=0"
      # No-op under Libreboot (no UEFI) but harmless and useful if the EFI
      # fallback path is ever taken.
      "efi=disable_early_pci_dma"

      # ── Kernel lockdown ───────────────────────────────────────────────────
      # confidentiality blocks: /dev/mem, /dev/kmem, /dev/port, kexec_load,
      # PCI BAR access, MSR writes, hibernation-to-disk, unsigned module load,
      # BPF tracing of kernel memory. Stronger than "integrity" — also denies
      # *reads* of kernel memory by privileged processes.
      "lockdown=confidentiality"
    ];

    # ── Thunderbolt ────────────────────────────────────────────────────────
    # PCIe-tunneled-over-USB-C is the dominant DMA attack surface on this
    # laptop. With the driver blacklisted the kernel never exposes the TB
    # controller's PCIe tunnel, so a malicious TB device cannot establish a
    # DMA channel. The USB-C port itself keeps working for:
    #   - PD charging (handled by the EC, not by the kernel)
    #   - plain USB devices like a YubiKey (USB-C → xHCI mux, independent
    #     of the thunderbolt driver)
    # What's lost: TB3 docks, TB displays, eGPUs. Acceptable trade.
    # firewire-* defensively blacklisted even though T480 has no FW port.
    # btusb blacklisted because bluetooth is disabled (bluetooth.nix); kills
    # the kernel binding to the M.2 BT radio (Intel 8087:0032) outright.
    blacklistedKernelModules = [ "thunderbolt" "firewire-core" "firewire-ohci" "firewire-sbp2" "btusb" "bluetooth" ];
  };

  # ── AppArmor ─────────────────────────────────────────────────────────────
  # MAC framework — confines browsers and other userspace high-risk processes.
  # killUnconfinedConfinables=true means: if a binary has a profile but starts
  # before AppArmor loads, kill it rather than let it run unconfined.
  security.apparmor = {
    enable = true;
    killUnconfinedConfinables = true;
    packages = [ pkgs.apparmor-profiles ];
  };

  # ── USBGuard ─────────────────────────────────────────────────────────────
  # Block-by-default for newly inserted USB devices. Devices already plugged
  # in at daemon start are allowed (presentDevicePolicy=allow), so the
  # internal webcam, card reader, fingerprint reader and a mouse plugged in
  # at boot all work without listing.
  #
  # The allowlist for *new* inserts is declared here via services.usbguard.rules
  # — this makes the policy nix-store-managed (immutable, reinstall-safe) and
  # disables the IPC-driven `usbguard allow-device -p` workflow. To trust a
  # new device, add an `allow id <vid>:<pid>` line below and rebuild.
  #
  # Find a device's id:
  #   sudo usbguard list-devices
  services.usbguard = {
    enable = true;
    IPCAllowedUsers = [ username "root" ];
    rules = ''
      # Yubico security keys — all models (FIDO, OTP, CCID, 5-series, etc).
      # Vendor-wide so spare/replacement keys work without a rebuild.
      allow id 1050:*
    '';
    implicitPolicyTarget = "block";
    presentDevicePolicy = "allow";        # devices at daemon start: trust
    presentControllerPolicy = "allow";    # internal xHCI controllers: trust
    insertedDevicePolicy = "apply-policy"; # new inserts: consult rules above
    dbus.enable = true;
  };

  environment.systemPackages = with pkgs; [
    usbguard          # CLI for list-devices (finding vid:pid to declare)
  ];
}
