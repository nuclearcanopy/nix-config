{
  # Synaptics PS/2 touchpad tuning + threaded i8042 IRQs.
  # rate=200 selects high-rate report mode. synaptics_intertouch=0 keeps psmouse
  # on PS/2 (auto-switch to RMI4-over-SMBus regresses to ~63Hz on TM3471-020).
  # resetafter=0 disables the periodic chip reset that caused micro-stutters.
  # Steady-state polling is ~100Hz only when paired with SMBus-enabled coreboot
  # (libreboot-nidhoggr patch); without it, ~70Hz.
  nixos.modules.trackpad-synaptics = { pkgs, ... }: {
    boot.extraModprobeConfig = ''
      options psmouse synaptics_intertouch=0 resetafter=0 rate=200
    '';

    # Thread hardirqs so the i8042 serio IRQ runs as a SCHED_FIFO kthread.
    # Promotes serio to RT priority so cursor input never queues behind a
    # busy compositor or a background CPU spike.
    boot.kernelParams = [ "threadirqs" ];

    # i8042 IRQ threads: keyboard (1) and AUX (12, trackpad + trackpoint).
    # SCHED_FIFO 50: above default tasks, well below typical RT audio (80+).
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
    # default tasks so a Firefox/Steam/MCP burst can't preempt it.
    services.ananicy.extraRules = [
      { name = "sway"; nice = -10; }
    ];
  };
}
