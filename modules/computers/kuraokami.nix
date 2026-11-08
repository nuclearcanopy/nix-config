{ config, inputs, ... }:

{
  nixos.configurations.kuraokami = {
    username = inputs.identity.usernames.kuraokami;
    module = { pkgs, unstable, username, ... }:
    let
      # Onboard Realtek RTL8168h (r8169) link stability. The link will not hold
      # while 1000baseT/Full is in the advertisement: it comes up and drops
      # carrier milliseconds later, forever, so NM can never activate the
      # device. The flap happens even though the switch only offers 10/100 and
      # 1G is never actually negotiated, so "it negotiated 100Mbps" is NOT
      # evidence the cap applied. Autoneg stays ON by design: forcing
      # `speed 100 duplex full autoneg off` also works, but relies on the
      # switch's parallel detection and risks a duplex mismatch.
      # Advertisement bits:
      #   0x001 10baseT/Half   0x002 10baseT/Full
      #   0x004 100baseT/Half  0x008 100baseT/Full
      # 0x00c is exactly what `ethtool -s enp4s0 speed 100` produces, which is
      # the only setting observed to hold; 10baseT is left out rather than
      # guessed at.
      #
      # Timing is the whole problem here. r8169 attaches the PHY in its open
      # path, not at probe, so at the udev "add" event there are no link modes
      # to read or write yet, and anything written there is wiped by the
      # attach. So bring the interface up ourselves, then poll until the PHY
      # reports an advertisement, cap it, and only stop once the cap reads back
      # stable (the attach can still reset it a beat later).
      #
      # The 1000baseT guard makes this idempotent, which is load-bearing:
      # `ethtool -s` always restarts autonegotiation, so re-applying
      # unconditionally from a link-up hook would flap the link forever.
      linkCap100 = pkgs.writeShellScript "r8169-cap-100" ''
        ${pkgs.iproute2}/bin/ip link set enp4s0 up || true

        stable=0
        i=0
        while [ "$i" -lt 60 ]; do
          adv=$(${pkgs.ethtool}/bin/ethtool enp4s0 \
            | ${pkgs.gnused}/bin/sed -n '/Advertised link modes/,/Advertised pause/p')
          case "$adv" in
            *1000baseT*)
              # phy is live but still offering 1G
              stable=0
              ${pkgs.ethtool}/bin/ethtool -s enp4s0 autoneg on advertise 0x00c
              ;;
            *baseT*)
              # cap is in place; want a few consecutive reads before trusting it
              stable=$((stable + 1))
              [ "$stable" -ge 3 ] && exit 0
              ;;
            *)
              # phy not attached yet, nothing to read
              stable=0
              ;;
          esac
          i=$((i + 1))
          sleep 1
        done

        echo "enp4s0: phy never settled on a 10/100 advertisement" >&2
        exit 1
      '';
    in
    {
      imports = [
        ../../hosts/kuraokami/hardware-configuration.nix
        inputs.agenix.nixosModules.default
        config.nixos.modules.desktop-base

        # ── kuraokami-specific (AMD desktop) ──────────────────────────
        config.nixos.modules.boot-amd
        config.nixos.modules.gpu-amd
        config.nixos.modules.graphics-amd
        config.nixos.modules.cpu-governor-performance
        config.nixos.modules.audio-jack
        config.nixos.modules.openrazer
        config.nixos.modules.thunar
        config.nixos.modules.nix-gc

        # MCA/EDAC decoding. Scoped to this host, not desktop-base: it exists
        # because of the 2026-11-08 data fabric sync flood on the 5900X, and
        # nidhoggr has no such history.
        config.nixos.modules.rasdaemon

        # runs generic-linux binaries (boomi atom's bundled corretto jre)
        config.nixos.modules.nix-ld

        # LVFS firmware updates. Desktop-only: see the module for why nidhoggr
        # (Libreboot, no capsule path) deliberately goes without.
        config.nixos.modules.fwupd
      ];

      # ── host-specific ────────────────────────────────────────────────
      time.timeZone = inputs.identity.location.timeZone;

      zramSwap = {
        enable = true;
        algorithm = "zstd";
        memoryPercent = 33;
      };

      # Pulled in by the netdev's device unit, so it runs at boot and again on
      # any driver rebind. Deliberately NOT a udev RUN+= rule: that fires at
      # the "add" event, before the PHY is attached, where the script has
      # nothing to read and its write would not survive (that is exactly how
      # the cap silently no-op'd and the link flapped on 2026-11-08). It is
      # also not ordered before NetworkManager: the script waits on hardware,
      # and blocking NM on that would turn a dead NIC into a slow boot.
      systemd.services.r8169-cap-100 = {
        description = "cap enp4s0 link advertisement at 100baseT";
        wantedBy = [ "sys-subsystem-net-devices-enp4s0.device" ];
        after = [ "sys-subsystem-net-devices-enp4s0.device" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${linkCap100}";
          TimeoutStartSec = "90s";
        };
      };

      # And again on every NM link-up: a PHY or driver reset restores the full
      # advertisement including 1000baseT, and the unit above only runs when the
      # device appears.
      networking.networkmanager.dispatcherScripts = [{
        source = pkgs.writeShellScript "r8169-cap-100-dispatch" ''
          if [ "$1" = "enp4s0" ] && [ "$2" = "up" ]; then
            exec ${linkCap100}
          fi
        '';
        type = "basic";
      }];

      # ── home-manager users ───────────────────────────────────────────
      home-manager.users.${username} = {
        imports = [
          config.homeManager.modules.desktop-home-base

          # ── kuraokami-specific ──────────────────────────────────────
          config.homeManager.modules.asunder
          config.homeManager.modules.steam-home
          config.homeManager.modules.vkbasalt
          config.homeManager.modules.user-packages
          config.homeManager.modules.prism-mullvad
        ];

        waybar.profile = "kuraokami";
      };
    };
  };
}
