{
  # Persistent hardware-error logging (MCE/CPU, PCIe AER, EDAC memory).
  #
  # Added 2026-11-08 after kuraokami hard-reset with a Data Fabric sync flood:
  #   x86/amd: Previous system reset reason [0x08000800]: an uncorrected error
  #            caused a data fabric sync flood event
  #   mce: [Hardware Error]: CPU 0:  Bank 27 baa000000000080b  (PIE, PCC+TCC)
  #   mce: [Hardware Error]: CPU 10: Bank 0  bc00080001010135  (LS_V2, poison)
  # The identical Bank 0 status word had appeared 9 days earlier from CPU 22.
  # CPU 10 and 22 are SMT siblings of one physical core (core_id 12, CCD1), so
  # a single core threw two uncorrected cache errors and escalated from
  # survivable to fatal.
  #
  # Without rasdaemon the only trace of a fatal MCE is the two-line retained-
  # bank dump the next boot happens to print, and nothing at all survives for
  # errors that do not reset the box. rasdaemon keeps a decoded SQLite history
  # (`ras-mc-ctl --errors`, `--summary`) with per-bank and per-core
  # attribution, which is what makes "same core again?" answerable.
  #
  # Deliberately universal rather than kuraokami-only: silent hardware decay is
  # not host-specific, and the cost is one small daemon.
  nixos.modules.rasdaemon = {
    hardware.rasdaemon = {
      enable = true;
      # Record to the on-disk DB, not just the journal, so history outlives
      # journal rotation.
      record = true;
    };
  };
}
