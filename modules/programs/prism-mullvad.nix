{
  # prismlauncher wrapped with mullvad-exclude so minecraft egresses around the
  # mullvad tunnel; servers that ban shared vpn exit ips see the real isp
  # address. symlinkJoin keeps prism's icons/desktop entry/mime data and swaps
  # only the binary, so the desktop entry's `Exec=prismlauncher` resolves to the
  # wrapper. jdks is overridden so Prism's AutomaticJava picks the LTS (21)
  # ahead of 25 on any MC version that accepts both. Imported on kuraokami,
  # whose Mullvad split-tunnel wrapper keeps Minecraft outside the VPN.
  homeManager.modules.prism-mullvad = { pkgs, ... }:
    let
      prism = pkgs.prismlauncher.override { jdks = with pkgs; [ jdk21 jdk25 jdk17 jdk8 ]; };
      launcher = pkgs.writeShellScript "prismlauncher-novpn" ''
        exec mullvad-exclude ${prism}/bin/prismlauncher "$@"
      '';
      prismNoVpn = pkgs.symlinkJoin {
        name = "prismlauncher-novpn";
        paths = [ prism ];
        postBuild = ''
          rm -f $out/bin/prismlauncher
          install -Dm755 ${launcher} $out/bin/prismlauncher
        '';
      };
    in
    {
      home.packages = [ prismNoVpn ];
    };
}
