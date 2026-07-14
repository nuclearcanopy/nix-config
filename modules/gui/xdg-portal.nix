{
  # xdg-desktop-portal-wlr's systemd unit is launched with `--config=<store>`
  # which pins the ini and makes ~/.config files inert; the chooser must be
  # set here. `simple` mode calls chooser_cmd once and expects it to print
  # `Monitor: <name>` on stdout. Wrap sway's output list into bemenu (a
  # visible top-of-screen dropdown) so there's no ambiguity about a picker
  # being on-screen. Falls back to nothing selected on Escape.
  nixos.modules.xdg-portal = { pkgs, ... }:
    let
      chooser = pkgs.writeShellScript "xdpw-chooser" ''
        set -eu
        sel=$(${pkgs.sway}/bin/swaymsg -r -t get_outputs \
          | ${pkgs.jq}/bin/jq -r '.[] | select(.active) | .name' \
          | ${pkgs.bemenu}/bin/bemenu -p 'share screen:' -i)
        [ -n "$sel" ] && printf 'Monitor: %s\n' "$sel"
      '';
    in
    {
      xdg.portal = {
        enable = true;
        config.common.default = "*";
        extraPortals = [ pkgs.xdg-desktop-portal-wlr ];
        wlr = {
          enable = true;
          settings.screencast = {
            chooser_type = "simple";
            chooser_cmd = "${chooser}";
            max_fps = 30;
          };
        };
      };
    };
}
