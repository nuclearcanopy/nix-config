{
  # TPM2 disabled: PCR 0 (firmware) changed when moving to Libreboot, and
  # PCR 7 (Secure Boot) is gone. To re-enroll after Libreboot stabilizes:
  #   sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme0n1p2
  #   sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0 /dev/nvme0n1p2
  nixos.modules.tpm2-off = {
    security.tpm2 = {
      enable = false;
      pkcs11.enable = false;
      tctiEnvironment.enable = false;
    };
  };
}
