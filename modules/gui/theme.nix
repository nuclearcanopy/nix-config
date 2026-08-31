{
  homeManager.modules.theme = { pkgs, lib, config, ... }:

    let
      # Pitch-black OLED palette, ported from firefox userChrome.
      oledCss = ''
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
        gtk3.extraCss = oledCss;
        gtk4.theme = null;
        gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
        gtk4.extraCss = oledCss;
      };

      dconf.settings = {
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
        };
      };

      # Qt apps (and Chromium/Helium's "use Qt" appearance path) read the Qt
      # palette, not the GTK3/4 OLED CSS above. adwaita-qt can't do pure black
      # (hardcoded grey), so drive Qt with qt6ct + a Fusion custom palette that
      # mirrors the GTK OLED colors exactly (black #000000, grey text #949494).
      qt = {
        enable = true;
        platformTheme.name = "qtct";
        qt6ctSettings.Appearance = {
          style = "Fusion";
          custom_palette = true;
          color_scheme_path = "${config.xdg.configHome}/qt6ct/colors/oled.conf";
          icon_theme = "Adwaita";
          standard_dialogs = "default";
        };
        qt5ctSettings.Appearance = {
          style = "Fusion";
          custom_palette = true;
          color_scheme_path = "${config.xdg.configHome}/qt6ct/colors/oled.conf";
          icon_theme = "Adwaita";
          standard_dialogs = "default";
        };
      };

      # Helium/Chromium is Qt6; the HM "qtct" preset points QT_QPA_PLATFORMTHEME
      # at qt5ct, which Qt6 apps ignore. Force qt6ct so Helium picks up the OLED
      # palette. Trade-off: Qt5-only apps (e.g. qjackctl) fall back to Fusion's
      # default light palette; there is no single env value that themes both.
      home.sessionVariables.QT_QPA_PLATFORMTHEME = lib.mkForce "qt6ct";
      systemd.user.sessionVariables.QT_QPA_PLATFORMTHEME = lib.mkForce "qt6ct";

      # qt6ct/qt5ct color scheme: 21 QPalette roles per state (active, disabled,
      # inactive), #aarrggbb. Pure-black backgrounds, grey text, matching the
      # oledCss above. inactive mirrors active so unfocused windows stay black.
      # Highlight/HighlightedText (roles 12/13) are #3a3a3a on white, mirroring
      # accent_bg_color in the GTK CSS: light enough to read against the black
      # background, still greyscale. Chromium's Qt path uses QPalette::Highlight
      # for page + omnibox text selection *and* for the new-tab "+" button, so
      # those two cannot be coloured separately (verified 2026-08-25 by running
      # a scratch profile against a palette with Highlight/Window/Link set to
      # three distinct debug colors). An accent blue was tried and reverted for
      # that reason. Link (14) stays grey for the same reason.
      #
      # Note on Helium tabs: with the Qt theme active (extensions.theme
      # .system_theme = 2) Chromium paints the frame, tab strip, inactive tabs,
      # the *active* tab and the toolbar all from QPalette::Button. With
      # Button = #000000 there is no color left to mark the selected tab, so a
      # pure-black chrome and a visible active tab are mutually exclusive here.
      # The two escapes, both declined: the Classic theme in
      # helium://settings/appearance (frame #1e2020, active tab #3a3c3c), or a
      # theme extension loaded via `--load-extension`, whose manifest separates
      # `frame` from `toolbar` (measured black frame + #1a1a1a active tab) at
      # the cost of dropping Helium off the Qt palette entirely, which turns its
      # menus and omnibox dropdown chromium-grey. Black was chosen.
      xdg.configFile."qt6ct/colors/oled.conf".text = ''
        [ColorScheme]
        active_colors=#ff949494, #ff000000, #ff272727, #ff1c1c1c, #ff000000, #ff171717, #ff949494, #ffffffff, #ff949494, #ff000000, #ff000000, #ff000000, #ff3a3a3a, #ffffffff, #ffb0b0b0, #ff6e6e6e, #ff000000, #ff000000, #ff000000, #ff949494, #ff4d4d4d
        disabled_colors=#ff4d4d4d, #ff000000, #ff1c1c1c, #ff141414, #ff000000, #ff000000, #ff4d4d4d, #ffffffff, #ff4d4d4d, #ff000000, #ff000000, #ff000000, #ff171717, #ff4d4d4d, #ff4d4d4d, #ff4d4d4d, #ff000000, #ff000000, #ff000000, #ff4d4d4d, #ff333333
        inactive_colors=#ff949494, #ff000000, #ff272727, #ff1c1c1c, #ff000000, #ff171717, #ff949494, #ffffffff, #ff949494, #ff000000, #ff000000, #ff000000, #ff3a3a3a, #ffffffff, #ffb0b0b0, #ff6e6e6e, #ff000000, #ff000000, #ff000000, #ff949494, #ff4d4d4d
      '';
    };
}
