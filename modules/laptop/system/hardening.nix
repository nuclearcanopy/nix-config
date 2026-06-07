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
    blacklistedKernelModules = [ "thunderbolt" "firewire-core" "firewire-ohci" "firewire-sbp2" ];
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
  # in at daemon start are allowed (so the internal webcam, fingerprint
  # reader, and bluetooth dongle on the M.2 card keep working without
  # bootstrap). New devices need explicit approval.
  #
  # Bootstrap (one-time, after the first rebuild that enables this):
  #   sudo usbguard generate-policy | sudo tee /var/lib/usbguard/rules.conf
  #   sudo systemctl restart usbguard
  # That snapshot becomes the persistent allowlist.
  #
  # Allow a new device:
  #   sudo usbguard list-devices                 # find the id
  #   sudo usbguard allow-device <id> -p         # -p = persist to rules.conf
  #
  # Note: rules.conf lives in /var/lib and does NOT survive a reinstall.
  # Re-run the bootstrap after a fresh install.
  services.usbguard = {
    enable = true;
    IPCAllowedUsers = [ username "root" ];
    ruleFile = "/var/lib/usbguard/rules.conf";
    implicitPolicyTarget = "block";
    presentDevicePolicy = "allow";        # devices at daemon start: trust
    presentControllerPolicy = "allow";    # internal xHCI controllers: trust
    insertedDevicePolicy = "apply-policy"; # new inserts: consult rules.conf
    dbus.enable = true;
  };

  # Ensure rules.conf exists empty so usbguard doesn't fail to start on a
  # fresh system before the bootstrap command has been run.
  systemd.tmpfiles.rules = [
    "f /var/lib/usbguard/rules.conf 0600 root root - -"
  ];

  environment.systemPackages = with pkgs; [
    usbguard          # CLI for list-devices, allow-device, generate-policy
  ];
}
