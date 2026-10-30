{
  # Shared infrastructure for the light/dark theme toggle (set-theme-mode,
  # wired up fully once every themed app has a dark/light pair declared).
  # Design + canonical color mapping: docs/gui.md.
  homeManager.modules.theme-mode = { pkgs, config, ... }:

    let
      mkBemenuSh = flags: ''
        export BEMENU_FLAGS=(${flags})
      '';

      darkFlags = ''-i -c -l 5 -W 0.20 -B 0 -p "" --fn "monospace 16" --tb "#000000" --tf "#cccccc" --fb "#000000" --ff "#cccccc" --nb "#000000" --nf "#888888" --ab "#000000" --af "#888888" --hb "#000000" --hf "#ffffff" --sb "#000000" --sf "#ffffff" --scb "#000000" --scf "#888888"'';
      lightFlags = ''-i -c -l 5 -W 0.20 -B 0 -p "" --fn "monospace 16" --tb "#ffffff" --tf "#303030" --fb "#ffffff" --ff "#303030" --nb "#ffffff" --nf "#606060" --ab "#ffffff" --af "#606060" --hb "#ffffff" --hf "#000000" --sb "#ffffff" --sf "#000000" --scb "#ffffff" --scf "#606060"'';

      configHome = config.xdg.configHome;
      stateFile = "${config.xdg.stateHome}/theme-mode/current";
      firefoxChrome = "${config.home.homeDirectory}/.mozilla/firefox/default/chrome";

      setThemeMode = pkgs.writeShellScriptBin "set-theme-mode" ''
        set -euo pipefail

        state_file="${stateFile}"
        mode="''${1:-toggle}"
        quiet=false
        [ "''${2:-}" = "--quiet" ] && quiet=true

        case "$mode" in
          restore)
            mode=$(cat "$state_file" 2>/dev/null || echo dark)
            ;;
          toggle)
            current=$(cat "$state_file" 2>/dev/null || echo dark)
            if [ "$current" = "light" ]; then mode=dark; else mode=light; fi
            ;;
        esac

        case "$mode" in
          light|dark) ;;
          *) echo "usage: set-theme-mode {light|dark|toggle|restore} [--quiet]" >&2; exit 1 ;;
        esac

        # plain symlink swaps, never editing file contents in place. every
        # target pair is declared twice by nix (dark.*/light.*); see
        # docs/gui.md for the full per-app mechanism table.
        ln -sfn "${configHome}/gtk-3.0/gtk-$mode.css" "${configHome}/gtk-3.0/gtk.css"
        ln -sfn "${configHome}/gtk-4.0/gtk-$mode.css" "${configHome}/gtk-4.0/gtk.css"
        ln -sfn "${configHome}/qt6ct/colors/$mode.conf" "${configHome}/qt6ct/colors/current.conf"
        ln -sfn "${configHome}/waybar/style-$mode.css" "${configHome}/waybar/current.css"
        ln -sfn "${configHome}/mako/colors-$mode.ini" "${configHome}/mako/colors.ini"
        ln -sfn "${configHome}/theme-mode/bemenu-$mode.sh" "${configHome}/theme-mode/bemenu.sh"
        ln -sfn "${configHome}/alacritty/colors-$mode.toml" "${configHome}/alacritty/current-colors.toml"
        ln -sfn "${configHome}/sway/colors-$mode.conf" "${configHome}/sway/colors.conf"
        # Guarded, unlike the pairs above: firefoxChrome sits under
        # ~/.mozilla/firefox/default, which is a psd symlink into tmpfs. If psd
        # has not populated it yet the ln fails, and under `set -euo pipefail`
        # that used to abort the whole script, so the state-file write and
        # every reload below silently never ran. theme-mode-restore failed on
        # literally every boot this way; see the After=psd.service ordering on
        # the unit, which fixes the common case but not a slow psd sync.
        ln -sfn "${firefoxChrome}/userChrome-$mode.css" "${firefoxChrome}/userChrome.css" 2>/dev/null || true
        ln -sfn "${firefoxChrome}/userContent-$mode.css" "${firefoxChrome}/userContent.css" 2>/dev/null || true

        mkdir -p "$(dirname "$state_file")"
        printf '%s\n' "$mode" > "$state_file"

        # best-effort reloads; a missing daemon (e.g. no session bus yet
        # during restore) must not abort the symlink work above.
        # dconf, not gsettings: glib is not installed anywhere in this config,
        # so the three `gsettings set` calls these replace were silently
        # no-ops and the runtime color-scheme never actually moved. this is
        # also what xdg-desktop-portal-gtk serves as org.freedesktop.appearance,
        # which is how ghostty follows the toggle; see docs/gui.md.
        if [ "$mode" = "dark" ]; then gtk_theme="Adwaita-dark"; else gtk_theme="Adwaita"; fi
        ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-$mode'" 2>/dev/null || true
        ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/gtk-theme "'$gtk_theme'" 2>/dev/null || true
        makoctl reload >/dev/null 2>&1 || true
        swaymsg reload >/dev/null 2>&1 || true
        pkill -RTMIN+6 waybar 2>/dev/null || true

        if ! $quiet; then
          notify-send "Theme changed" "Restart Firefox to see the new look" 2>/dev/null || true
        fi
      '';
    in
    {
      xdg.configFile."theme-mode/bemenu-dark.sh".text = mkBemenuSh darkFlags;
      xdg.configFile."theme-mode/bemenu-light.sh".text = mkBemenuSh lightFlags;

      # bemenu.sh is a symlink set-theme-mode flips between bemenu-{dark,light}.sh.
      # Wrappers source it fresh on every invocation, so no reload is needed.
      # Named themed-bemenu(-run) to not collide with pkgs.bemenu's own bemenu-run.
      home.packages = [
        setThemeMode
        (pkgs.writeShellScriptBin "themed-bemenu" ''
          source "$HOME/.config/theme-mode/bemenu.sh"
          exec bemenu "''${BEMENU_FLAGS[@]}" "$@"
        '')
        (pkgs.writeShellScriptBin "themed-bemenu-run" ''
          source "$HOME/.config/theme-mode/bemenu.sh"
          exec bemenu-run "''${BEMENU_FLAGS[@]}" "$@"
        '')
      ];

      # Reapplies the persisted mode on every login and after every
      # home-manager switch (a rebuild resets the nix-level dark default,
      # i.e. the gtk/dconf settings and the first-run symlink targets).
      systemd.user.services.theme-mode-restore = {
        Unit = {
          Description = "Reapply persisted light/dark theme mode";
          PartOf = [ "sway-session.target" ];
          # psd.service too: the firefox userChrome symlinks live under a psd
          # tmpfs profile, and ordering on sway-session alone raced it (psd up
          # at 20:14:44, this ran at :46, psd finished syncing at :48).
          After = [ "sway-session.target" "psd.service" ];
          Wants = [ "psd.service" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${setThemeMode}/bin/set-theme-mode restore --quiet";
        };
        Install.WantedBy = [ "sway-session.target" ];
      };
    };
}
