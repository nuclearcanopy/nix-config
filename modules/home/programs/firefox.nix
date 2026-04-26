{ pkgs, ... }:

{
  programs.firefox = {
    enable = true;

    policies = {
      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          allowed_private_browsing = true;
        };
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
          allowed_private_browsing = true;
        };
      };
      # allow ublock on mozilla pages
      "3rdparty".Extensions."uBlock0@raymondhill.net".adminSettings = {
        allowGenericFiltering = true;
      };
    };

    profiles.default = {
      isDefault = true;

      extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
        ublock-origin
        darkreader
        bitwarden
        sponsorblock
        localcdn
        violentmonkey
      ];

      # stricter filters
      extensions.force = true;
      extensions.settings = {
        "uBlock0@raymondhill.net".settings = {
          selectedFilterLists = [
            "user-filters"
            "ublock-filters"
            "ublock-badware"
            "ublock-privacy"
            "ublock-quick-fixes"
            "ublock-unbreak"
            "easylist"
            "adguard-spyware-url"
            "easyprivacy"
            "urlhaus-1"
            "ublock-cookies-easylist"
            "ublock-cookies-adguard"
            "easylist-cookies"
            "adguard-cookies"
            "adguard-url-tracking-protection"
          ];
        };
      };

      # match oled
      userChrome = ''
        .tabbrowser-tab[label="New Tab"] .tab-icon-image,
        .tabbrowser-tab[label="New Tab"] .tab-icon-stack {
          display: none !important;
        }

        :root {
          --lwt-accent-color: #000000 !important;
          --toolbar-bgcolor: #000000 !important;
          --lwt-toolbar-bgcolor: #000000 !important;
          --toolbar-bottom-separator: #000000 !important;
          --lwt-tabs-border-color: #000000 !important;
          --arrowpanel-background: #000000 !important;
          --panel-background: #000000 !important;
          --sidebar-background-color: #000000 !important;
          --toolbar-field-background-color: #0a0a0a !important;
          --toolbar-field-focus-background-color: #0a0a0a !important;
          --urlbar-box-bgcolor: #0a0a0a !important;
          --urlbar-box-focus-bgcolor: #0a0a0a !important;

          --toolbarbutton-icon-fill-attention: #666666 !important;

          --toolbar-color: rgb(117, 117, 117) !important;
          --lwt-text-color: rgb(117, 117, 117) !important;
          --toolbar-field-color: rgb(148, 148, 148) !important;
          --toolbar-field-focus-color: rgb(148, 148, 148) !important;
          --urlbar-popup-url-color: rgb(148, 148, 148) !important;
          --urlbar-popup-action-color: rgb(117, 117, 117) !important;
          --tab-text-color: rgb(117, 117, 117) !important;
          --lwt-tab-text: rgb(117, 117, 117) !important;
          --arrowpanel-color: rgb(129, 129, 129) !important;
          --panel-color: rgb(129, 129, 129) !important;

          --toolbarbutton-icon-fill: rgb(77, 77, 77) !important;
          --lwt-toolbarbutton-icon-fill: rgb(77, 77, 77) !important;
          --lwt-toolbarbutton-icon-fill-attention: rgb(67, 67, 67) !important;
          --toolbar-field-icon-fill-attention: rgb(148, 148, 148) !important;
          --urlbar-icon-fill-attention: rgb(148, 148, 148) !important;
          --urlbar-searchbar-icon-fill: rgb(148, 148, 148) !important;
          --urlbar-focused-icon-fill: rgb(148, 148, 148) !important;
          --identity-box-icon-fill-attention: rgb(148, 148, 148) !important;
          --link-color: rgb(148, 148, 148) !important;

          --tab-selected-bgcolor: #171717 !important;
          --lwt-selected-tab-background-color: #171717 !important;

          --toolbar-field-focus-border-color: #000000 !important;
          --lwt-toolbar-field-highlight: #272727 !important;
          --lwt-toolbar-field-highlight-text: rgb(148, 148, 148) !important;
          --arrowpanel-dimmed: #1c1c1c !important;
          --tab-line-color: #000000 !important;
          --lwt-tab-line-color: #000000 !important;
          --tab-loading-fill: #000000 !important;
          --chrome-content-separator-color: #000000 !important;
          --toolbox-border-bottom-color: #000000 !important;
          --sidebar-border-color: #000000 !important;
          --focus-outline-color: transparent !important;
        }

        #navigator-toolbox {
          border-bottom: none !important;
        }
        #sidebar-box,
        #sidebar-splitter {
          border-color: #000000 !important;
        }
        #tabbrowser-tabbox {
          border: none !important;
        }

        .titlebar-buttonbox-container,
        .titlebar-close,
        .titlebar-min,
        .titlebar-max,
        .titlebar-restore {
          display: none !important;
        }

        *:focus,
        *:focus-visible {
          outline: none !important;
          box-shadow: none !important;
        }

        .tabbrowser-tab[selected] .tab-background {
          background-color: #171717 !important;
        }

        #star-button[starred] {
          fill: #666666 !important;
        }
        #star-button[starred] .toolbarbutton-icon {
          fill: #666666 !important;
        }

        #urlbar[focused] #urlbar-background,
        #urlbar[open] #urlbar-background,
        #searchbar:focus-within {
          background-color: #0a0a0a !important;
        }

        #urlbar *,
        #urlbar-container *,
        #urlbar[focused] *,
        #urlbar[open] *,
        .urlbar-icon,
        .searchbar-icon,
        #identity-icon,
        #tracking-protection-icon,
        .urlbar-search-mode-indicator,
        #urlbar .search-one-offs image,
        .search-panel-header,
        .searchbar-engine-one-off-item,
        #urlbar-label-box,
        #urlbar-search-mode-indicator-title,
        .urlbar-input::placeholder {
          fill: rgb(148, 148, 148) !important;
          color: rgb(148, 148, 148) !important;
          -moz-context-properties: fill, fill-opacity !important;
        }

        #urlbar-input {
          color: rgb(148, 148, 148) !important;
          -moz-appearance: none !important;
          caret-color: rgb(148, 148, 148) !important;
        }
        #urlbar[focused] > #urlbar-input-container > #urlbar-input {
          color: rgb(148, 148, 148) !important;
        }
        :root #urlbar-input {
          color: rgb(148, 148, 148) !important;
        }
        input#urlbar-input.urlbar-input {
          color: rgb(148, 148, 148) !important;
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
        browser[type="content-primary"],
        #browser,
        .browserStack,
        .browserContainer {
          background-color: #000000 !important;
        }
      '';

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

      bookmarks = {
        force = true;
        settings = [
          { name = "Proton Mail"; url = "https://mail.proton.me/u/0/inbox"; keyword = "pmail"; }
          { name = "Proton Drive"; url = "https://drive.proton.me/"; keyword = "pdrive"; }
          { name = "Reddit"; url = "https://www.reddit.com/"; keyword = "reddit"; }
          { name = "NixOS Packages"; url = "https://search.nixos.org/packages"; keyword = "nixpkgs"; }
          { name = "Google Classroom"; url = "https://classroom.google.com/u/1/"; keyword = "class"; }
          { name = "Piracy Megathread"; url = "https://www.reddit.com/r/Piracy/wiki/megathread/"; keyword = "megathread"; }
          { name = "YouTube Music"; url = "https://music.youtube.com/"; keyword = "ytm"; }
          { name = "Warframe Market"; url = "https://warframe.market/"; keyword = "wfm"; }
          { name = "Dexonline"; url = "https://dexonline.ro/"; keyword = "dex"; }
          { name = "WhatsApp"; url = "https://web.whatsapp.com/"; keyword = "wa"; }
          { name = "YouTube"; url = "https://www.youtube.com/"; keyword = "yt"; }
          { name = "GitHub"; url = "https://github.com/"; keyword = "gh"; }
          { name = "Codeberg"; url = "https://codeberg.org/"; keyword = "cb"; }
        ];
      };

      search = {
        force = true;
        default = "ddg";
        engines = {
          "nuclearcanopy" = {
            urls = [{ template = "https://search.local/?q={searchTerms}"; }];
            definedAliases = [ "@a" ];
          };
          "ddg".metaData.alias = "@d";
          "google".metaData.hidden = true;
          "bing".metaData.hidden = true;
          "amazondotcom-us".metaData.hidden = true;
          "ebay".metaData.hidden = true;
          "wikipedia".metaData.hidden = true;
        };
      };

      settings = {
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

        "layout.css.devPixelsPerPx" = "1.4";

        "sidebar.verticalTabs" = true;

        # Fast startup optimizations
        "browser.startup.homepage.abouthome_cache.enabled" = true;
        "browser.sessionstore.interval" = 60000;  # 60s instead of 15s
        "browser.sessionstore.idleDelay" = 10000;
        "browser.startup.preXulSkeletonUI" = false;  # skip skeleton (faster cold start)
        "browser.tabs.animate" = false;
        "browser.urlbar.trimURLs" = false;  # less processing
        "browser.cache.disk.enable" = true;
        "browser.cache.disk.smart_size.enabled" = false;
        "browser.cache.disk.capacity" = 512000;  # 500MB cache
        "browser.cache.memory.enable" = true;
        "browser.cache.memory.capacity" = 131072;  # 128MB memory cache
        "image.mem.decode_bytes_at_a_time" = 65536;  # faster image decode
        "gfx.webrender.all" = true;
        "layers.acceleration.force-enabled" = true;
        "gfx.webrender.compositor.force-enabled" = true;

        # Hardware video decode (benefits all systems)
        "media.ffmpeg.vaapi.enabled" = true;
        "media.hardware-video-decoding.force-enabled" = true;

        "browser.ml.enable" = false;
        "browser.ml.chat.enabled" = false;
        "browser.ml.chat.sidebar" = false;
        "browser.ml.linkPreview.enabled" = false;

        "browser.translations.enable" = true;
        "browser.translations.automaticallyPopup" = true;

        "extensions.formautofill.addresses.enabled" = false;
        "extensions.formautofill.creditCards.enabled" = false;

        "signon.rememberSignons" = false;
        "signon.autofillForms" = false;
        "signon.generation.enabled" = false;
        "signon.firefoxRelay.feature" = "disabled";
        "signon.management.page.breach-alerts.enabled" = false;

        # kill telemetry
        "datareporting.healthreport.uploadEnabled" = false;
        "datareporting.policy.dataSubmissionEnabled" = false;
        "toolkit.telemetry.enabled" = false;
        "toolkit.telemetry.unified" = false;
        "toolkit.telemetry.archive.enabled" = false;
        "toolkit.telemetry.newProfilePing.enabled" = false;
        "toolkit.telemetry.shutdownPingSender.enabled" = false;
        "toolkit.telemetry.updatePing.enabled" = false;
        "toolkit.telemetry.bhrPing.enabled" = false;
        "toolkit.telemetry.firstShutdownPing.enabled" = false;
        "toolkit.telemetry.dau.enabled" = false;
        "toolkit.telemetry.reportingpolicy.firstRun" = false;
        "app.update.background.rolledout" = false;
        "dom.security.unexpected_system_load_telemetry_enabled" = false;
        "toolkit.coverage.opt-out" = true;
        "toolkit.coverage.endpoint.base" = "";

        "dom.security.https_only_mode" = true;
        "dom.security.https_only_mode_ever_enabled" = true;

        # privacy on shutdown
        "privacy.sanitize.sanitizeOnShutdown" = true;
        "privacy.clearOnShutdown.cookies" = false;
        "privacy.clearOnShutdown_v2.cookiesAndStorage" = true;
        "privacy.clearOnShutdown.cache" = true;
        "privacy.clearOnShutdown.history" = true;
        "privacy.clearOnShutdown.sessions" = true;
        "privacy.clearOnShutdown.offlineApps" = false;
        "privacy.clearOnShutdown.formdata" = true;
        "privacy.clearOnShutdown.downloads" = true;
        "privacy.clearOnShutdown.siteSettings" = false;

        "app.shield.optoutstudies.enabled" = false;
        "app.normandy.enabled" = false;
        "app.normandy.api_url" = "";

        "browser.discovery.enabled" = false;

        "browser.theme.toolbar-theme" = 0;

        "browser.newtabpage.activity-stream.showSearch" = false;
        "browser.newtabpage.activity-stream.showSponsoredCheckboxes" = false;
        "browser.toolbars.bookmarks.visibility" = "never";

        "browser.contentblocking.category" = "strict";
        "privacy.trackingprotection.enabled" = true;
        "privacy.trackingprotection.socialtracking.enabled" = true;
        "privacy.trackingprotection.emailtracking.enabled" = true;
        "privacy.fingerprintingProtection" = false;
        "privacy.resistFingerprinting" = false;
        "privacy.resistFingerprinting.letterboxing" = false;
        "privacy.query_stripping.enabled" = true;
        "privacy.query_stripping.enabled.pbmode" = true;
        "privacy.bounceTrackingProtection.mode" = 1;
        "privacy.annotate_channels.strict_list.enabled" = true;

        # avoid site breakage
        "extensions.webcompat.enable_shims" = true;
        "privacy.webcompat.fixMajorSiteIssues" = true;

        "network.prefetch-next" = false;
        "network.http.speculative-parallel-limit" = 0;
        "network.early-hints.preconnect.max_connections" = 0;
        "network.captive-portal-service.enabled" = false;
        "network.connectivity-service.enabled" = false;
        "network.http.referer.disallowCrossSiteRelaxingDefault.top_navigation" = true;

        "browser.safebrowsing.downloads.remote.enabled" = false;
        "browser.safebrowsing.downloads.remote.block_potentially_unwanted" = false;
        "browser.safebrowsing.downloads.remote.block_uncommon" = false;
        "browser.safebrowsing.downloads.remote.url" = "";
        "browser.safebrowsing.provider.google4.dataSharingURL" = "";

        # region + captive portal
        "browser.region.update.enabled" = false;
        "browser.region.network.url" = "";
        "captivedetect.canonicalURL" = "";

        "security.tls.enable_0rtt_data" = false;

        "clipboard.autocopy" = false;

        # streaming drm
        "media.eme.enabled" = true;

        "devtools.debugger.remote-enabled" = false;
        "devtools.console.stdout.chrome" = false;
        "browser.dom.window.dump.enabled" = false;
      };
    };
  };
}
