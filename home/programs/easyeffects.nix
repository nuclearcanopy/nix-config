{ pkgs, ... }:

{
  home.packages = [ pkgs.easyeffects ];

  xdg.configFile."easyeffects/db/bassEnhancerrc" = {
    force = true;
    text = ''
      [soe][BassEnhancer#0]
      amount=2.50
      harmonics=8.5
      scope=150
    '';
  };

  xdg.configFile."easyeffects/easyeffectsrc" = {
    force = true;
    text = ''
      [StreamInputs]
      inputDevice=alsa_input.usb-audio-technica_AT2020USB_-00.analog-stereo
      [StreamOutputs]
      outputDevice=alsa_output.usb-FIIO_FiiO_K11_R2R-01.analog-stereo
      plugins=bass_enhancer#0
      visiblePage=pluginsPage
      visiblePlugin=bass_enhancer#0
      [Window]
      height=1033
      width=952
    '';
  };
}
