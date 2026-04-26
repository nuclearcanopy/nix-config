{ pkgs, ... }:

# 80ms keyboard debounce via interception-tools.
# Filters chatter: if the same key is pressed again within 80ms of release, ignore it.
# Works at the evdev level — affects all keyboards, transparent to Sway/Wayland.
let
  evdev-debounce = pkgs.stdenv.mkDerivation {
    pname = "evdev-debounce";
    version = "1.0.0";
    dontUnpack = true;

    buildPhase = ''
      cat > debounce.c << 'CSRC'
      #include <stdio.h>
      #include <stdlib.h>
      #include <string.h>
      #include <linux/input.h>
      #include <time.h>

      #define MAX_KEY 256

      static struct timespec last_release[MAX_KEY];

      static long ms_since(struct timespec *then) {
          struct timespec now;
          clock_gettime(CLOCK_MONOTONIC, &now);
          return (now.tv_sec - then->tv_sec) * 1000 +
                 (now.tv_nsec - then->tv_nsec) / 1000000;
      }

      int main(int argc, char *argv[]) {
          int debounce_ms = argc > 1 ? atoi(argv[1]) : 80;
          struct input_event ev;

          memset(last_release, 0, sizeof(last_release));
          setbuf(stdin, NULL);
          setbuf(stdout, NULL);

          while (fread(&ev, sizeof(ev), 1, stdin) == 1) {
              if (ev.type == EV_KEY && ev.code < MAX_KEY) {
                  if (ev.value == 0) {
                      clock_gettime(CLOCK_MONOTONIC, &last_release[ev.code]);
                  } else if (ev.value == 1 && last_release[ev.code].tv_sec > 0) {
                      if (ms_since(&last_release[ev.code]) < debounce_ms)
                          continue;
                  }
              }
              if (fwrite(&ev, sizeof(ev), 1, stdout) != 1)
                  break;
          }
          return 0;
      }
      CSRC
    '';

    installPhase = ''
      mkdir -p $out/bin
      $CC -O2 -o $out/bin/evdev-debounce debounce.c
    '';
  };
in
{
  services.interception-tools = {
    enable = true;
    udevmonConfig = ''
      - JOB: "${pkgs.interception-tools}/bin/intercept -g $DEVNODE | ${evdev-debounce}/bin/evdev-debounce 80 | ${pkgs.interception-tools}/bin/uinput -d $DEVNODE"
        DEVICE:
          NAME: ".*[Kk]eyboard.*"
    '';
  };
}
