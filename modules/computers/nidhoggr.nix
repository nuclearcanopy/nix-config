{ config, inputs, ... }:

{
  nixos.configurations.nidhoggr = {
    username = "loki";
    module = { unstable, username, lib, ... }: {
      imports = [
        ../../hosts/nidhoggr/hardware-configuration.nix
        inputs.agenix.nixosModules.default
        config.nixos.modules.desktop-base

        # ── nidhoggr-specific (T480 laptop) ───────────────────────────
        config.nixos.modules.hardening-physical
        config.nixos.modules.system-packages-laptop
        config.nixos.modules.boot-t480
        config.nixos.modules.boot-optimizations
        config.nixos.modules.audio-basic
        config.nixos.modules.graphics-intel
        config.nixos.modules.trackpoint
        config.nixos.modules.trackpad-synaptics
        config.nixos.modules.keyd-internal-kbd
        config.nixos.modules.bluetooth
        config.nixos.modules.logitech
        config.nixos.modules.pcmanfm
        config.nixos.modules.network-laptop
        config.nixos.modules.mullvad-graphical-target
        config.nixos.modules.earlyoom
        config.nixos.modules.displaymanager-ly
        config.nixos.modules.tpm2-off
        config.nixos.modules.luks-initrd
        config.nixos.modules.virtualisation

        # ── power buckets ─────────────────────────────────────────────
        config.nixos.modules.tlp
        config.nixos.modules.cpu-modes
        config.nixos.modules.thinkfan
        config.nixos.modules.undervolt
        config.nixos.modules.power-suspend
        config.nixos.modules.brightness-persist
      ];

      # ── host-specific ────────────────────────────────────────────────
      zramSwap = {
        enable = true;
        algorithm = "zstd";
        memoryPercent = 50;
      };

      virtualisation.docker.enableOnBoot = false; # socket-activated; starts on demand

      # fwupd was dropped 2026-09-06. On this machine it could see exactly one
      # updatable device (the WD SN720 NVMe): Libreboot has no UEFI capsule
      # path so the BIOS/EC are not updatable through it, and the Thunderbolt
      # controller is behind blacklisted modules. That left a resident daemon
      # plus an fwupd-refresh timer making a periodic outbound LVFS request on
      # a lockdown-mode Mullvad host. For the occasional SSD firmware check:
      #   nix shell nixpkgs#fwupd -c fwupdmgr get-updates

      # Text-to-speech daemon. nixpkgs enables it by default; nothing here
      # asks for it and it costs ~1.2GB of closure plus a resident user
      # service. Turning it off loses Firefox "Read Aloud" and screen-reader
      # support, and nothing else (it is output-only; the mic path is
      # pipewire/wireplumber and is untouched).
      services.speechd.enable = false;

      # scx_lavd comes from the shared cpu-scheduler bucket (for the AMD desktop).
      # Discarded here 2026-08-22: on a 4c/8t laptop its gains over stock EEVDF
      # didn't justify a resident BPF scheduler. ananicy + irqbalance stay.
      services.scx.enable = lib.mkForce false;

      # ── home-manager users ───────────────────────────────────────────
      home-manager.users.${username} = {
        imports = [
          config.homeManager.modules.desktop-home-base

          # ── nidhoggr-specific ───────────────────────────────────────
          config.homeManager.modules.swayidle
          config.homeManager.modules.easyeffects-service
          config.homeManager.modules.user-packages-laptop
        ];

        waybar.profile = "laptop";

        # Kaby Lake iGPU + strict VT-d IOMMU stalls the forced Wayland dmabuf
        # compositor path during scroll (every tile attach hits per-op IOMMU
        # flushes). Let Firefox auto-detect the safer path here; kuraokami
        # keeps the forced variants because AMD + iommu.strict is cheap.
        programs.firefox.profiles.default.settings = {
          "gfx.webrender.compositor.force-enabled" = lib.mkForce false;
          "gfx.canvas.accelerated.force-enabled" = lib.mkForce false;
        };
      };
    };
  };
}
