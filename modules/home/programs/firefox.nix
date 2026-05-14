{ lib, pkgs, ... }:
{
  # Pre-warm Firefox at login so opening it feels instant.
  # Starts firefox with about:blank, waits for the window to appear in sway,
  # then moves it to the scratchpad. When the user opens firefox, the existing
  # process handles the request and opens a new window instantly.
  # Uses sway-session.target so SWAYSOCK is available.
  systemd.user.services.firefox-preload = {
    Unit = {
      Description = "Firefox scratchpad prelauncher";
      After = [ "sway-session.target" ];
      PartOf = [ "sway-session.target" ];
      X-StopOnReconfiguration = false;
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.writeShellScript "firefox-preload" ''
        # If firefox is already running (e.g. service restarted by a rebuild mid-session),
        # don't open a new window into the user's existing browser — just wait until
        # all firefox processes are gone, then exit so systemd restarts us cleanly.
        if ${pkgs.procps}/bin/pgrep -u "$(id -u)" -f "${pkgs.firefox}/bin/firefox" >/dev/null 2>&1; then
          while ${pkgs.procps}/bin/pgrep -u "$(id -u)" -f "${pkgs.firefox}/bin/firefox" >/dev/null 2>&1; do
            sleep 3
          done
          exit 0
        fi

        # Poll the sway tree every 250ms until firefox's window appears, then
        # immediately move it to scratchpad. sway does not reliably emit a
        # "window:new" IPC event for firefox's initial surface, so event
        # subscription doesn't work here. Polling is simple and correct:
        # firefox takes several seconds to start so the 250ms interval means
        # at most one frame of visible flash before it's hidden.
        # Switch to workspace 10 so firefox opens there — never visible on ws1.
        # Immediately schedule a switch back to ws1 in the background, then
        # poll until firefox appears and hide it to scratchpad.
        ${pkgs.sway}/bin/swaymsg workspace 10 2>/dev/null || true

        (
          sleep 0.2
          ${pkgs.sway}/bin/swaymsg workspace 1 2>/dev/null || true
          i=0
          while [ $i -lt 60 ]; do
            sleep 0.25
            ${pkgs.sway}/bin/swaymsg -t get_tree 2>/dev/null \
              | ${pkgs.gnugrep}/bin/grep -q '"app_id": "firefox"' \
            && {
              ${pkgs.sway}/bin/swaymsg '[app_id="firefox"] move scratchpad' 2>/dev/null || true
              break
            }
            i=$((i + 1))
          done
        ) &

        exec ${pkgs.firefox}/bin/firefox about:blank
      ''}";
      Nice = 19;
      CPUWeight = 1;
      Restart = "on-failure";
      RestartSec = "5";
    };
    Install.WantedBy = [ "sway-session.target" ];
  };

  # PSD leaves a stale symlink at ~/.mozilla/firefox/<profile> pointing to
  # /run/user/1000/psd/... (tmpfs) on crash/unclean shutdown. HM's
  # linkGeneration can't mkdir through a broken symlink, so restore from
  # PSD's backup first.
  home.activation.fixPsdFirefoxLinks = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    for profile in default compat; do
      link="$HOME/.mozilla/firefox/$profile"
      backup="$HOME/.mozilla/firefox/''${profile}-backup"
      if [ -L "$link" ] && [ ! -e "$link" ]; then
        $DRY_RUN_CMD rm "$link"
        if [ -d "$backup" ]; then
          $DRY_RUN_CMD cp -a "$backup" "$link"
        else
          $DRY_RUN_CMD mkdir "$link"
        fi
      fi
    done
  '';

  home.packages = [
    (pkgs.writeShellScriptBin "firefox-compat" ''
      exec firefox --no-remote -P compat "$@"
    '')
  ];

  xdg.desktopEntries.firefox-compat = {
    name = "Firefox (Compat)";
    exec = "firefox-compat %U";
    terminal = false;
    categories = [ "Network" "WebBrowser" ];
  };

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
        "mullvad-extension@mullvad.net" = {
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
        violentmonkey
        mullvad
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

        # "strict" can break some auth flows (missing/invalid session tokens).
        "browser.contentblocking.category" = "standard";
        "privacy.trackingprotection.enabled" = true;
        "privacy.trackingprotection.socialtracking.enabled" = true;
        "privacy.trackingprotection.emailtracking.enabled" = true;
        "privacy.fingerprintingProtection" = false;
        "privacy.resistFingerprinting" = false;
        "privacy.resistFingerprinting.letterboxing" = false;
        # Can break some login flows that (unfortunately) carry tokens in query params.
        "privacy.query_stripping.enabled" = false;
        "privacy.query_stripping.enabled.pbmode" = false;
        # Can break some cross-site auth redirect flows (e.g. hosting panels).
        "privacy.bounceTrackingProtection.mode" = 0;
        "privacy.annotate_channels.strict_list.enabled" = true;

        # avoid site breakage
        "extensions.webcompat.enable_shims" = true;
        "privacy.webcompat.fixMajorSiteIssues" = true;

        "network.prefetch-next" = false;
        "network.http.speculative-parallel-limit" = 0;
        "network.early-hints.preconnect.max_connections" = 0;
        "network.captive-portal-service.enabled" = false;
        "network.connectivity-service.enabled" = false;
        # Some auth flows still (unfortunately) depend on Referer during redirects.
        "network.http.referer.disallowCrossSiteRelaxingDefault.top_navigation" = false;

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

        # Spoof the most common user agent (Chrome on Windows) to blend in with the crowd.
        "general.useragent.override" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36";
      };
    };

    # A less-hardened profile for sites with fragile auth flows (e.g. cPanel).
    # Launch via `firefox-compat`.
    profiles.compat = {
      id = 1;
      name = "compat";

      settings = {
        "browser.contentblocking.category" = "standard";

        # Prefer compatibility over privacy for this profile.
        "network.cookie.cookieBehavior" = 0;
        "privacy.bounceTrackingProtection.mode" = 0;
        "privacy.query_stripping.enabled" = false;
        "privacy.query_stripping.enabled.pbmode" = false;
        "network.http.referer.disallowCrossSiteRelaxingDefault.top_navigation" = false;
      };

      extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
        bitwarden
      ];
    };

  };
}
