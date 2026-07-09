{
  # Universal firefox profile: ublock filter list, telemetry kills, OLED userChrome,
  # privacy.clearOnShutdown, bookmarks, search engines, VA-API in RDD, battery
  # savers, tab unloading on low memory, 4 content procs, devPixelsPerPx 1.35.
  # The behavior matches what nidhoggr needs; kuraokami inherits the same defaults.
  # Plus a "compat" profile for sites with fragile auth flows.
  homeManager.modules.firefox = { config, lib, pkgs, ... }: {
    # PSD leaves a stale symlink at ~/.config/mozilla/firefox/<profile> pointing to
    # /run/user/1000/psd/... (tmpfs) on crash/unclean shutdown. HM's
    # linkGeneration can't mkdir through a broken symlink, so restore from
    # PSD's backup first.
    home.activation.fixPsdFirefoxLinks = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
      for profile in default compat google; do
        link="${config.xdg.configHome}/mozilla/firefox/$profile"
        backup="${config.xdg.configHome}/mozilla/firefox/''${profile}-backup"
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
      (pkgs.symlinkJoin {
        name = "firefox-compat";
        paths = [ pkgs.firefox ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          mv $out/bin/firefox $out/bin/firefox-compat
          wrapProgram $out/bin/firefox-compat \
            --add-flags "--no-remote -P compat"
        '';
      })
      (pkgs.symlinkJoin {
        name = "firefox-google";
        paths = [ pkgs.firefox ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          mv $out/bin/firefox $out/bin/firefox-google
          wrapProgram $out/bin/firefox-google \
            --add-flags "--no-remote -P google"
        '';
      })
    ];

    xdg.desktopEntries.firefox-compat = {
      name = "Firefox (Compat)";
      exec = "firefox-compat %U";
      terminal = false;
      categories = [ "Network" "WebBrowser" ];
    };

    xdg.desktopEntries.firefox-google = {
      name = "Firefox (Google)";
      exec = "firefox-google %U";
      terminal = false;
      categories = [ "Network" "WebBrowser" ];
    };

    programs.firefox = {
      configPath = "${config.xdg.configHome}/mozilla/firefox";
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
          bitwarden
          sponsorblock
          auto-tab-discard
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
            userFilters = ''
              wikipedia.org##.nag-trigger
              wikipedia.org###centralNotice
              wikipedia.org##[id$="banner-nag"]
              www.wikipedia.org##.overlay-banner-mini-message
              www.wikipedia.org##.visible.overlay-banner-mini
              wikipedia.org###frb-inline
            '';
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

            --toolbar-color: rgb(80, 80, 80) !important;
            --lwt-text-color: rgb(80, 80, 80) !important;
            --toolbar-field-color: rgb(148, 148, 148) !important;
            --toolbar-field-focus-color: rgb(148, 148, 148) !important;
            --urlbar-popup-url-color: rgb(148, 148, 148) !important;
            --urlbar-popup-action-color: rgb(80, 80, 80) !important;
            --tab-text-color: rgb(80, 80, 80) !important;
            --lwt-tab-text: rgb(80, 80, 80) !important;
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

          #urlbar .urlbar-background,
          #urlbar[focused] .urlbar-background,
          #urlbar[open] .urlbar-background,
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
            { name = "NYT Crossword"; url = "https://www.nytimes.com/crosswords"; keyword = "nyt"; }
            { name = "TryHackMe"; url = "https://tryhackme.com/dashboard"; keyword = "thm"; }
          ];
        };

        search = {
          force = true;
          default = "ddg";
          engines = {
            "self" = {
              urls = [{ template = "https://searxng.local/?q={searchTerms}"; }];
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

          "layout.css.devPixelsPerPx" = "1.35";

          "sidebar.verticalTabs" = true;

          # Session restore: disabled; Firefox re-enables via prefs.js on ungraceful
          # shutdown, user.js always wins at startup so these stick permanently
          "browser.sessionstore.resume_from_crash" = false;
          "browser.sessionstore.resume_session_once" = false;
          "browser.startup.page" = 1;

          # VA-API in the sandboxed RDD media process (without this, VA-API is
          # unused despite media.ffmpeg.vaapi.enabled below).
          "media.rdd-ffmpeg.enabled" = true;

          # Battery/CPU savers (also a perf win on desktop, so applied universally).
          "media.av1.enabled" = false;          # AV1 software decode is brutal on CPU
          "layout.frame_rate" = 60;              # cap at 60fps
          "dom.battery.enabled" = false;         # don't expose battery to sites
          "beacon.enabled" = false;              # no background analytics pings
          "dom.push.enabled" = false;            # no push notifications
          "dom.push.connection.enabled" = false;

          # Tab unloading for memory/battery
          "browser.tabs.unloadOnLowMemory" = true;

          # 8 content procs: 4c/8t with HT enabled (via Libreboot patch),
          # 32GB RAM so headroom is not the constraint. More procs = tabs
          # load in parallel and one heavy tab doesn't starve the others.
          "dom.ipc.processCount" = 8;

          # Fast startup optimizations
          "browser.startup.homepage.abouthome_cache.enabled" = true;
          "browser.sessionstore.interval" = 120000;  # 2min sessionstore writes
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

          # Wayland GPU paths: EGL backend, dmabuf zero-copy, HW compositor.
          # force-enabled bypasses probe failures on iGPUs where the auto-detect
          # is too conservative (intel mesa on older HW).
          "gfx.x11-egl.force-enabled" = true;
          "widget.dmabuf.force-enabled" = true;
          "gfx.webrender.compositor" = true;
          "gfx.webrender.compositor.force-enabled" = true;
          "gfx.canvas.accelerated.force-enabled" = true;  # canvas via GPU

          # Perf: kill UI micro-animations, cap background tabs at 30fps,
          # loosen vsync accounting, decode images off main thread.
          "toolkit.cosmeticAnimations.enabled" = false;
          "layout.throttled_frame_rate" = 30;
          "layout.frame_rate.precise" = false;
          "image.decode-immediately.enabled" = true;

          # Honor system dark theme so sites with prefers-color-scheme go dark
          # without a per-page rewriter extension.
          "ui.systemUsesDarkTheme" = 1;
          "layout.css.prefers-color-scheme.content-override" = 0;

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

          # kill telemetry + usage pings
          "datareporting.healthreport.uploadEnabled" = false;
          "datareporting.policy.dataSubmissionEnabled" = false;
          "datareporting.usage.uploadEnabled" = false;
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

          # compat profile exists for fragile auth flows; use strict here
          "browser.contentblocking.category" = "strict";
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

      # Locked-down profile for Google services. Cookies persist so login
      # survives shutdown; everything else (cache/history/sessions/formdata)
      # is wiped. Strict ETP + FPP fingerprinting + HTTPS-only + query
      # stripping + bounce tracking blocked. Launch via `firefox-google`.
      profiles.google = {
        id = 2;
        name = "google";

        extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
          ublock-origin
          bitwarden
        ];

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

        bookmarks = {
          force = true;
          settings = [
            { name = "Gmail"; url = "https://mail.google.com/"; keyword = "gmail"; }
            { name = "Drive"; url = "https://drive.google.com/"; keyword = "gdrive"; }
            { name = "Docs"; url = "https://docs.google.com/"; keyword = "gdocs"; }
            { name = "Calendar"; url = "https://calendar.google.com/"; keyword = "gcal"; }
            { name = "Classroom"; url = "https://classroom.google.com/u/1/"; keyword = "class"; }
            { name = "YouTube"; url = "https://www.youtube.com/"; keyword = "yt"; }
            { name = "YouTube Music"; url = "https://music.youtube.com/"; keyword = "ytm"; }
          ];
        };

        search = {
          force = true;
          default = "ddg";
          engines = {
            "ddg".metaData.alias = "@d";
            "google".metaData.alias = "@g";
            "bing".metaData.hidden = true;
            "amazondotcom-us".metaData.hidden = true;
            "ebay".metaData.hidden = true;
            "wikipedia".metaData.hidden = true;
          };
        };

        settings = {
          "browser.startup.page" = 1;

          # Strict ETP plus the newer fingerprinting protection (FPP); RFP
          # is off because it breaks too many Google-internal flows.
          "browser.contentblocking.category" = "strict";
          "privacy.trackingprotection.enabled" = true;
          "privacy.trackingprotection.socialtracking.enabled" = true;
          "privacy.trackingprotection.emailtracking.enabled" = true;
          "privacy.trackingprotection.cryptomining.enabled" = true;
          "privacy.trackingprotection.fingerprinting.enabled" = true;
          "privacy.fingerprintingProtection" = true;
          "privacy.resistFingerprinting" = false;
          "privacy.resistFingerprinting.letterboxing" = false;
          "privacy.query_stripping.enabled" = true;
          "privacy.query_stripping.enabled.pbmode" = true;
          "privacy.bounceTrackingProtection.mode" = 1;
          "privacy.annotate_channels.strict_list.enabled" = true;
          "privacy.partition.network_state" = true;
          "privacy.firstparty.isolate" = false;

          "dom.security.https_only_mode" = true;
          "dom.security.https_only_mode_ever_enabled" = true;

          # Keep cookies/storage so Google login persists; wipe the rest.
          "privacy.sanitize.sanitizeOnShutdown" = true;
          "privacy.clearOnShutdown.cookies" = false;
          "privacy.clearOnShutdown_v2.cookiesAndStorage" = false;
          "privacy.clearOnShutdown.cache" = true;
          "privacy.clearOnShutdown.history" = true;
          "privacy.clearOnShutdown.sessions" = true;
          "privacy.clearOnShutdown.offlineApps" = false;
          "privacy.clearOnShutdown.formdata" = true;
          "privacy.clearOnShutdown.downloads" = true;
          "privacy.clearOnShutdown.siteSettings" = false;

          "extensions.formautofill.addresses.enabled" = false;
          "extensions.formautofill.creditCards.enabled" = false;
          "signon.rememberSignons" = false;
          "signon.autofillForms" = false;
          "signon.generation.enabled" = false;
          "signon.firefoxRelay.feature" = "disabled";
          "signon.management.page.breach-alerts.enabled" = false;

          # Telemetry kills (mirror default profile).
          "datareporting.healthreport.uploadEnabled" = false;
          "datareporting.policy.dataSubmissionEnabled" = false;
          "datareporting.usage.uploadEnabled" = false;
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
          "dom.security.unexpected_system_load_telemetry_enabled" = false;
          "toolkit.coverage.opt-out" = true;
          "toolkit.coverage.endpoint.base" = "";
          "app.shield.optoutstudies.enabled" = false;
          "app.normandy.enabled" = false;
          "app.normandy.api_url" = "";
          "browser.discovery.enabled" = false;
          "browser.newtabpage.activity-stream.feeds.telemetry" = false;
          "browser.newtabpage.activity-stream.telemetry" = false;
          "browser.ping-centre.telemetry" = false;
          "browser.urlbar.eventTelemetry.enabled" = false;

          "dom.battery.enabled" = false;
          "beacon.enabled" = false;
          "dom.push.enabled" = false;
          "dom.push.connection.enabled" = false;

          "network.prefetch-next" = false;
          "network.http.speculative-parallel-limit" = 0;
          "network.early-hints.preconnect.max_connections" = 0;
          "network.captive-portal-service.enabled" = false;
          "network.connectivity-service.enabled" = false;

          "browser.safebrowsing.downloads.remote.enabled" = false;
          "browser.safebrowsing.downloads.remote.block_potentially_unwanted" = false;
          "browser.safebrowsing.downloads.remote.block_uncommon" = false;
          "browser.safebrowsing.downloads.remote.url" = "";
          "browser.safebrowsing.provider.google4.dataSharingURL" = "";

          "browser.region.update.enabled" = false;
          "browser.region.network.url" = "";
          "captivedetect.canonicalURL" = "";

          "security.tls.enable_0rtt_data" = false;

          "browser.ml.enable" = false;
          "browser.ml.chat.enabled" = false;
          "browser.ml.chat.sidebar" = false;
          "browser.ml.linkPreview.enabled" = false;

          "browser.toolbars.bookmarks.visibility" = "never";
          "layout.css.devPixelsPerPx" = "1.35";
          "ui.systemUsesDarkTheme" = 1;
          "layout.css.prefers-color-scheme.content-override" = 0;
        };
      };
    };
  };
}
