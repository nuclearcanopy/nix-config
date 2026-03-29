{ pkgs, ... }:

{
  programs.firefox = {
    enable = true;

    profiles.default = {
      isDefault = true;

      # extensions
      extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
        ublock-origin
        darkreader
        bitwarden
        # tampermonkey - unfree, install manually from AMO
      ];

      # userChrome.css - black toolbar theme
      userChrome = ''
        .tabbrowser-tab[label="New Tab"] .tab-icon-image,
        .tabbrowser-tab[label="New Tab"] .tab-icon-stack {
          display: none !important;
        }

        :root {
          --toolbar-bgcolor: #000000 !important;
          --lwt-accent-color: #000000 !important;
          --lwt-toolbarbutton-background: #000000 !important;
          --arrowpanel-background: #000000 !important;
          --sidebar-background-color: #000000 !important;
        }

        #navigator-toolbox,
        #TabsToolbar,
        #nav-bar,
        #PersonalToolbar,
        #titlebar {
          background-color: #000000 !important;
        }

        #tabbrowser-tabpanels,
        #appcontent,
        browser[type="content"],
        browser[type="content-primary"] {
          background-color: #000000 !important;
        }

        #browser,
        .browserStack,
        .browserContainer {
          background-color: #000000 !important;
        }
      '';

      # userContent.css - blank new tab
      userContent = ''
        @-moz-document url("about:home"),url("about:newtab"),url("about:blank"){
          body * {
            display: none !important;
            visibility: hidden !important;
          }
          body, html {
            background-color: #000000 !important;
          }
        }
      '';

      # settings from librewolf
      settings = {
        # enable userChrome/userContent
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

        # dark theme
        "browser.theme.toolbar-theme" = 0;

        # search & new tab
        "browser.newtabpage.activity-stream.showSearch" = false;
        "browser.newtabpage.activity-stream.showSponsoredCheckboxes" = false;
        "browser.toolbars.bookmarks.visibility" = "never";

        # privacy - tracking protection
        "browser.contentblocking.category" = "strict";
        "privacy.trackingprotection.enabled" = true;
        "privacy.trackingprotection.socialtracking.enabled" = true;
        "privacy.trackingprotection.emailtracking.enabled" = true;
        "privacy.fingerprintingProtection" = true;
        "privacy.resistFingerprinting.letterboxing" = true;
        "privacy.query_stripping.enabled" = true;
        "privacy.query_stripping.enabled.pbmode" = true;
        "privacy.bounceTrackingProtection.mode" = 1;
        "privacy.annotate_channels.strict_list.enabled" = true;

        # privacy - network
        "network.prefetch-next" = false;
        "network.http.speculative-parallel-limit" = 0;
        "network.early-hints.preconnect.max_connections" = 0;
        "network.captive-portal-service.enabled" = false;
        "network.connectivity-service.enabled" = false;
        "network.http.referer.disallowCrossSiteRelaxingDefault.top_navigation" = true;

        # privacy - safe browsing (disabled for privacy)
        "browser.safebrowsing.downloads.remote.enabled" = false;
        "browser.safebrowsing.downloads.remote.block_potentially_unwanted" = false;
        "browser.safebrowsing.downloads.remote.block_uncommon" = false;
        "browser.safebrowsing.downloads.remote.url" = "";
        "browser.safebrowsing.provider.google4.dataSharingURL" = "";

        # privacy - region & telemetry
        "browser.region.update.enabled" = false;
        "browser.region.network.url" = "";
        "captivedetect.canonicalURL" = "";

        # security
        "security.tls.enable_0rtt_data" = false;
        "dom.security.https_only_mode_ever_enabled" = true;

        # clipboard
        "clipboard.autocopy" = false;

        # drm (enabled for streaming)
        "media.eme.enabled" = true;

        # devtools
        "devtools.debugger.remote-enabled" = false;
        "devtools.console.stdout.chrome" = false;
        "browser.dom.window.dump.enabled" = false;
      };
    };
  };
}
