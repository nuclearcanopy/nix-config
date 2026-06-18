{
  homeManager.modules.theme = { pkgs, ... }:

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

        @define-color accent_bg_color       #272727;
        @define-color accent_fg_color       #949494;
        @define-color accent_color          #949494;

        @define-color theme_bg_color        #000000;
        @define-color theme_fg_color        #949494;
        @define-color theme_base_color      #000000;
        @define-color theme_text_color      #949494;
        @define-color theme_selected_bg_color #171717;
        @define-color theme_selected_fg_color #949494;
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
        entry selection, textview selection {
          background-color: #272727;
          color: #949494;
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
          background-color: #171717;
          color: #949494;
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
          color: #949494;
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
          background-color: #272727;
          background-image: none;
        }

        switch {
          background-color: #0a0a0a;
          color: #949494;
        }
        switch:checked {
          background-color: #272727;
        }
        switch slider {
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

      qt = {
        enable = true;
        platformTheme.name = "gtk";
      };
    };
}
