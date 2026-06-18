# Synaptics PS/2 touchpad tuning.
# rate=200 selects the chip's high-rate report mode.
# synaptics_intertouch=0 keeps psmouse on the PS/2 path and prevents an
# auto-switch to RMI4-over-SMBus, which on this particular chip
# (TM3471-020) regresses to ~63Hz.
# resetafter=0 disables psmouse's periodic chip reset, which otherwise
# introduces brief micro-stutters every few seconds.
# Steady-state polling is ~100Hz only when paired with the SMBus-enabled
# coreboot build (libreboot-nidhoggr patch). Without coreboot exposing
# pci 00:1f.4 the chip stays in a base mode and polls at ~70Hz even with
# rate=200 set; i2c-i801 init at coreboot time appears to put the chip
# in a higher-perf internal sampling mode that persists for the session
# even though Linux drives it via PS/2.
{ pkgs, ... }:

{
  boot.extraModprobeConfig = ''
    options psmouse synaptics_intertouch=0 resetafter=0 rate=200
  '';

  # Thread hardirqs so the i8042 serio IRQ handler runs as a SCHED_FIFO kthread.
  # Without threadirqs IRQs are non-preemptible; with it we can promote serio
  # to RT priority so cursor input never queues behind a busy compositor or a
  # background CPU spike.
  boot.kernelParams = [ "threadirqs" ];

  # i8042 IRQ threads: keyboard (1) and AUX (12, trackpad + trackpoint).
  # SCHED_FIFO 50: above default user tasks, well below typical RT audio (80+).
  systemd.services.serio-rt = {
    description = "Promote i8042 serio IRQ threads to SCHED_FIFO";
    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "serio-rt" ''
        for pid in $(${pkgs.procps}/bin/pgrep -f "irq/.*-i8042"); do
          ${pkgs.util-linux}/bin/chrt -f -p 50 "$pid" || true
        done
      '';
    };
  };

  # Sway processes cursor motion on its main thread; nice=-10 keeps it above
  # default user tasks so a Firefox/Steam/MCP burst can't preempt it.
  services.ananicy.extraRules = [
    { name = "sway"; nice = -10; }
  ];
}
