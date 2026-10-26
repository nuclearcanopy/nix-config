{
  homeManager.modules.theme = { pkgs, lib, config, ... }:

    let
      # Pitch-black OLED palette, ported from firefox userChrome. Mapped
      # 1:1 to lightCss below via the dark->light table in docs/gui.md.
      darkCss = ''
        @define-color window_bg_color       #000000;
        @define-color window_fg_color       #949494;
        @define-color view_bg_color         #000000;
        @define-color view_fg_color         #949494;
        @define-color headerbar_bg_color    #000000;
        @define-color headerbar_fg_color    #949494;
        @define-color headerbar_border_color #000000;
        @define-color headerbar_backdrop_color #000000;
        @define-color sidebar_bg_color      #000000;
        @define-color sidebar_fg_color      #949494;
        @define-color sidebar_backdrop_color #000000;
        @define-color secondary_sidebar_bg_color #000000;
        @define-color secondary_sidebar_fg_color #949494;
        @define-color card_bg_color         #0a0a0a;
        @define-color card_fg_color         #949494;
        @define-color popover_bg_color      #000000;
        @define-color popover_fg_color      #949494;
        @define-color dialog_bg_color       #000000;
        @define-color dialog_fg_color       #949494;
        @define-color thumbnail_bg_color    #0a0a0a;
        @define-color thumbnail_fg_color    #949494;
        @define-color shade_color           rgba(0, 0, 0, 0.5);
        @define-color scrollbar_outline_color #000000;
        @define-color borders               #000000;

        @define-color accent_bg_color       #3a3a3a;
        @define-color accent_fg_color       #ffffff;
        @define-color accent_color          #b0b0b0;

        @define-color theme_bg_color        #000000;
        @define-color theme_fg_color        #949494;
        @define-color theme_base_color      #000000;
        @define-color theme_text_color      #949494;
        @define-color theme_selected_bg_color #3a3a3a;
        @define-color theme_selected_fg_color #ffffff;
        @define-color insensitive_bg_color  #000000;
        @define-color insensitive_fg_color  #4d4d4d;

        window, .background, .view, scrolledwindow, viewport, dialog, popover, popover > contents, menu, .menu, .csd {
          background-color: #000000;
          color: #949494;
        }

        headerbar, .titlebar, headerbar.default-decoration {
          background-color: #000000;
          background-image: none;
          color: #949494;
          box-shadow: none;
          border-color: #000000;
        }

        entry, spinbutton, textview, textview text {
          background-color: #0a0a0a;
          color: #949494;
          border-color: #000000;
          box-shadow: none;
        }
        entry:focus, spinbutton:focus, textview:focus {
          outline: none;
          border-color: #000000;
          box-shadow: none;
        }
        entry selection, textview selection, selection, ::selection {
          background-color: #3a3a3a;
          color: #ffffff;
        }

        button, .button {
          background-color: #0a0a0a;
          background-image: none;
          color: #949494;
          border-color: #000000;
          box-shadow: none;
        }
        button:hover, .button:hover {
          background-color: #1c1c1c;
        }
        button:active, .button:active, button:checked, .button:checked {
          background-color: #272727;
        }
        button.flat, .button.flat {
          background-color: transparent;
        }
        button.flat:hover, .button.flat:hover {
          background-color: #1c1c1c;
        }

        row:selected, row:selected:focus, .activatable:selected, list row:selected {
          background-color: #3a3a3a;
          color: #ffffff;
        }
        row:hover, .activatable:hover {
          background-color: #1c1c1c;
        }

        notebook, notebook header, notebook tab, tabbar, tab {
          background-color: #000000;
          color: #757575;
          border-color: #000000;
        }
        notebook tab:checked, tab:checked, tab:selected {
          background-color: #171717;
          color: #ffffff;
          box-shadow: inset 0 -2px #4d4d4d;
        }

        scrollbar, scrollbar trough {
          background-color: #000000;
          border-color: #000000;
        }
        scrollbar slider {
          background-color: #1c1c1c;
          border: none;
          min-width: 6px;
          min-height: 6px;
        }
        scrollbar slider:hover {
          background-color: #272727;
        }

        separator, .separator {
          background-color: #000000;
          color: #000000;
          min-width: 0;
          min-height: 0;
        }

        tooltip, tooltip.background {
          background-color: #0a0a0a;
          color: #949494;
          border: none;
        }

        progressbar trough {
          background-color: #0a0a0a;
        }
        progressbar progress {
          background-color: #3a3a3a;
          background-image: none;
        }

        switch {
          background-color: #0a0a0a;
          color: #949494;
        }
        switch:checked {
          background-color: #3a3a3a;
        }
        switch slider {
          background-color: #4d4d4d;
        }
        switch:checked slider {
          background-color: #ffffff;
        }

        check:checked, radio:checked, check:indeterminate, radio:indeterminate {
          background-color: #3a3a3a;
          border-color: #3a3a3a;
          color: #ffffff;
        }

        button.suggested-action, .suggested-action {
          background-color: #3a3a3a;
          color: #ffffff;
        }
        button.suggested-action:hover, .suggested-action:hover {
          background-color: #4d4d4d;
        }

        *:focus, *:focus-visible {
          outline: none;
          box-shadow: none;
        }

        label.dim-label, .dim-label {
          color: #757575;
          opacity: 1;
        }
      '';

      lightCss = ''
        @define-color window_bg_color       #f0f0f0;
        @define-color window_fg_color       #2b2b2b;
        @define-color view_bg_color         #f0f0f0;
        @define-color view_fg_color         #2b2b2b;
        @define-color headerbar_bg_color    #f0f0f0;
        @define-color headerbar_fg_color    #2b2b2b;
        @define-color headerbar_border_color #f0f0f0;
        @define-color headerbar_backdrop_color #f0f0f0;
        @define-color sidebar_bg_color      #f0f0f0;
        @define-color sidebar_fg_color      #2b2b2b;
        @define-color sidebar_backdrop_color #f0f0f0;
        @define-color secondary_sidebar_bg_color #f0f0f0;
        @define-color secondary_sidebar_fg_color #2b2b2b;
        @define-color card_bg_color         #ffffff;
        @define-color card_fg_color         #2b2b2b;
        @define-color popover_bg_color      #f0f0f0;
        @define-color popover_fg_color      #2b2b2b;
        @define-color dialog_bg_color       #f0f0f0;
        @define-color dialog_fg_color       #2b2b2b;
        @define-color thumbnail_bg_color    #ffffff;
        @define-color thumbnail_fg_color    #2b2b2b;
        @define-color shade_color           rgba(0, 0, 0, 0.5);
        @define-color scrollbar_outline_color #f0f0f0;
        @define-color borders               #f0f0f0;

        @define-color accent_bg_color       #c7c7c7;
        @define-color accent_fg_color       #000000;
        @define-color accent_color          #5a5a5a;

        @define-color theme_bg_color        #f0f0f0;
        @define-color theme_fg_color        #2b2b2b;
        @define-color theme_base_color      #f0f0f0;
        @define-color theme_text_color      #2b2b2b;
        @define-color theme_selected_bg_color #c7c7c7;
        @define-color theme_selected_fg_color #000000;
        @define-color insensitive_bg_color  #f0f0f0;
        @define-color insensitive_fg_color  #a8a8a8;

        window, .background, .view, scrolledwindow, viewport, dialog, popover, popover > contents, menu, .menu, .csd {
          background-color: #f0f0f0;
          color: #2b2b2b;
        }

        headerbar, .titlebar, headerbar.default-decoration {
          background-color: #f0f0f0;
          background-image: none;
          color: #2b2b2b;
          box-shadow: none;
          border-color: #f0f0f0;
        }

        entry, spinbutton, textview, textview text {
          background-color: #ffffff;
          color: #2b2b2b;
          border-color: #f0f0f0;
          box-shadow: none;
        }
        entry:focus, spinbutton:focus, textview:focus {
          outline: none;
          border-color: #f0f0f0;
          box-shadow: none;
        }
        entry selection, textview selection, selection, ::selection {
          background-color: #c7c7c7;
          color: #000000;
        }

        button, .button {
          background-color: #ffffff;
          background-image: none;
          color: #2b2b2b;
          border-color: #f0f0f0;
          box-shadow: none;
        }
        button:hover, .button:hover {
          background-color: #e2e2e2;
        }
        button:active, .button:active, button:checked, .button:checked {
          background-color: #d4d4d4;
        }
        button.flat, .button.flat {
          background-color: transparent;
        }
        button.flat:hover, .button.flat:hover {
          background-color: #e2e2e2;
        }

        row:selected, row:selected:focus, .activatable:selected, list row:selected {
          background-color: #c7c7c7;
          color: #000000;
        }
        row:hover, .activatable:hover {
          background-color: #e2e2e2;
        }

        notebook, notebook header, notebook tab, tabbar, tab {
          background-color: #f0f0f0;
          color: #868686;
          border-color: #f0f0f0;
        }
        notebook tab:checked, tab:checked, tab:selected {
          background-color: #e8e8e8;
          color: #000000;
          box-shadow: inset 0 -2px #a8a8a8;
        }

        scrollbar, scrollbar trough {
          background-color: #f0f0f0;
          border-color: #f0f0f0;
        }
        scrollbar slider {
          background-color: #e2e2e2;
          border: none;
          min-width: 6px;
          min-height: 6px;
        }
        scrollbar slider:hover {
          background-color: #d4d4d4;
        }

        separator, .separator {
          background-color: #f0f0f0;
          color: #f0f0f0;
          min-width: 0;
          min-height: 0;
        }

        tooltip, tooltip.background {
          background-color: #ffffff;
          color: #2b2b2b;
          border: none;
        }

        progressbar trough {
          background-color: #ffffff;
        }
        progressbar progress {
          background-color: #c7c7c7;
          background-image: none;
        }

        switch {
          background-color: #ffffff;
          color: #2b2b2b;
        }
        switch:checked {
          background-color: #c7c7c7;
        }
        switch slider {
          background-color: #a8a8a8;
        }
        switch:checked slider {
          background-color: #000000;
        }

        check:checked, radio:checked, check:indeterminate, radio:indeterminate {
          background-color: #c7c7c7;
          border-color: #c7c7c7;
          color: #000000;
        }

        button.suggested-action, .suggested-action {
          background-color: #c7c7c7;
          color: #000000;
        }
        button.suggested-action:hover, .suggested-action:hover {
          background-color: #a8a8a8;
        }

        *:focus, *:focus-visible {
          outline: none;
          box-shadow: none;
        }

        label.dim-label, .dim-label {
          color: #868686;
          opacity: 1;
        }
      '';
    in
    {
      home.pointerCursor = {
        gtk.enable = true;
        x11.enable = true;
        sway.enable = true;
        name = "Adwaita";
        size = 24;
        package = pkgs.adwaita-icon-theme;
      };

      gtk = {
        enable = true;

        theme = {
          name = "Adwaita-dark";
          package = pkgs.gnome-themes-extra;
        };

        gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
        gtk4.theme = null;
        gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
      };

      # gtk3.extraCss/gtk4.extraCss would make HM own ~/.config/gtk-{3,4}.0/gtk.css
      # as an immutable symlink, which set-theme-mode needs to control at runtime.
      # Declare both variants under different names instead; set-theme-mode
      # symlinks gtk.css -> whichever one is active.
      xdg.configFile."gtk-3.0/gtk-dark.css".text = darkCss;
      xdg.configFile."gtk-3.0/gtk-light.css".text = lightCss;
      xdg.configFile."gtk-4.0/gtk-dark.css".text = darkCss;
      xdg.configFile."gtk-4.0/gtk-light.css".text = lightCss;

      dconf.settings = {
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
        };
      };

      # Qt apps read the Qt palette, not the GTK3/4 OLED CSS above. adwaita-qt
      # can't do pure black (hardcoded grey), so drive Qt with qt6ct + a Fusion
      # custom palette that mirrors the GTK OLED colors exactly (black
      # #000000, grey text #949494).
      qt = {
        enable = true;
        platformTheme.name = "qtct";
        qt6ctSettings.Appearance = {
          style = "Fusion";
          custom_palette = true;
          # current.conf is a symlink the toggle script (set-theme-mode)
          # flips between dark.conf/light.conf; never edited in place.
          color_scheme_path = "${config.xdg.configHome}/qt6ct/colors/current.conf";
          icon_theme = "Adwaita";
          standard_dialogs = "default";
        };
        qt5ctSettings.Appearance = {
          style = "Fusion";
          custom_palette = true;
          color_scheme_path = "${config.xdg.configHome}/qt6ct/colors/current.conf";
          icon_theme = "Adwaita";
          standard_dialogs = "default";
        };
      };

      # The HM "qtct" preset points QT_QPA_PLATFORMTHEME at qt5ct, which Qt6
      # apps ignore. Force qt6ct so any Qt6 app picks up the OLED palette.
      # Trade-off: Qt5-only apps (e.g. qjackctl) fall back to Fusion's default
      # light palette; there is no single env value that themes both.
      home.sessionVariables.QT_QPA_PLATFORMTHEME = lib.mkForce "qt6ct";
      systemd.user.sessionVariables.QT_QPA_PLATFORMTHEME = lib.mkForce "qt6ct";

      # qt6ct/qt5ct color scheme: 21 QPalette roles per state (active, disabled,
      # inactive), #aarrggbb. Pure-black backgrounds, grey text, matching the
      # darkCss above. Greyscale accent is deliberate: Chromium's Qt path
      # can't color page/omnibox selection separately from the new-tab button,
      # and pure-black chrome can't show a visible active tab at all.
      # Full investigation + declined alternatives (Helium, now removed): docs/gui.md
      xdg.configFile."qt6ct/colors/dark.conf".text = ''
        [ColorScheme]
        active_colors=#ff949494, #ff000000, #ff272727, #ff1c1c1c, #ff000000, #ff171717, #ff949494, #ffffffff, #ff949494, #ff000000, #ff000000, #ff000000, #ff3a3a3a, #ffffffff, #ffb0b0b0, #ff6e6e6e, #ff000000, #ff000000, #ff000000, #ff949494, #ff4d4d4d
        disabled_colors=#ff4d4d4d, #ff000000, #ff1c1c1c, #ff141414, #ff000000, #ff000000, #ff4d4d4d, #ffffffff, #ff4d4d4d, #ff000000, #ff000000, #ff000000, #ff171717, #ff4d4d4d, #ff4d4d4d, #ff4d4d4d, #ff000000, #ff000000, #ff000000, #ff4d4d4d, #ff333333
        inactive_colors=#ff949494, #ff000000, #ff272727, #ff1c1c1c, #ff000000, #ff171717, #ff949494, #ffffffff, #ff949494, #ff000000, #ff000000, #ff000000, #ff3a3a3a, #ffffffff, #ffb0b0b0, #ff6e6e6e, #ff000000, #ff000000, #ff000000, #ff949494, #ff4d4d4d
      '';

      # Light counterpart, same 21-role structure, every hex mapped through
      # the dark->light table in docs/gui.md. Toggled by set-theme-mode via
      # a symlink swap of qt6ct/colors/current.conf; this file is never
      # referenced directly by qt6ct's own config.
      xdg.configFile."qt6ct/colors/light.conf".text = ''
        [ColorScheme]
        active_colors=#ff2b2b2b, #fff0f0f0, #ffd4d4d4, #ffe2e2e2, #fff0f0f0, #ffe8e8e8, #ff2b2b2b, #ff000000, #ff2b2b2b, #fff0f0f0, #fff0f0f0, #fff0f0f0, #ffc7c7c7, #ff000000, #ff5a5a5a, #ff8a8a8a, #fff0f0f0, #fff0f0f0, #fff0f0f0, #ff2b2b2b, #ffa8a8a8
        disabled_colors=#ffa8a8a8, #fff0f0f0, #ffe2e2e2, #ffeeeeee, #fff0f0f0, #fff0f0f0, #ffa8a8a8, #ff000000, #ffa8a8a8, #fff0f0f0, #fff0f0f0, #fff0f0f0, #ffe8e8e8, #ffa8a8a8, #ffa8a8a8, #ffa8a8a8, #fff0f0f0, #fff0f0f0, #fff0f0f0, #ffa8a8a8, #ffcccccc
        inactive_colors=#ff2b2b2b, #fff0f0f0, #ffd4d4d4, #ffe2e2e2, #fff0f0f0, #ffe8e8e8, #ff2b2b2b, #ff000000, #ff2b2b2b, #fff0f0f0, #fff0f0f0, #fff0f0f0, #ffc7c7c7, #ff000000, #ff5a5a5a, #ff8a8a8a, #fff0f0f0, #fff0f0f0, #fff0f0f0, #ff2b2b2b, #ffa8a8a8
      '';
    };
}
