{ pkgs, ... }:

{
  home.packages = [ pkgs.easyeffects ];

  xdg.configFile = {
    "easyeffects/db/equalizerrc" = {
      force = true;
      text = ''
[soe][Equalizer#0#left]
band0Gain=3
band1Gain=2.3
band2Gain=1.8
band3Gain=1
band4Gain=1
band5Gain=0.7
band6Gain=0.35
band7Gain=0.3
band8Gain=0.3

[soe][Equalizer#0#right]
band0Gain=3
band1Gain=2.3
band2Gain=1.8
band3Gain=1
band4Gain=1
band5Gain=0.7
band6Gain=0.35
band7Gain=0.3
band8Gain=0.3 
      '';
    };

    "easyeffects/db/loudnessrc" = {
      force = true;
      text = ''
[soe][Loudness#0]
std=0
volume=-3
      '';
    };


    "easyeffects/easyeffectsrc" = {
      force = true;
      text = ''
[EffectsPipelines]
processAllInputs=false

[Presets]
lastLoadedOutputPreset=Perfect

[Spectrum]
spectrumFpsCap=120
spectrumShape=lines

[StreamInputs]
inputDevice=alsa_input.usb-audio-technica_AT2020USB_-00.analog-stereo

[StreamOutputs]
mostUsedPresets=Perfect
outputDevice=alsa_output.usb-FIIO_FiiO_K11_R2R-01.analog-stereo
plugins=loudness#0,equalizer#0,stereo_tools#0
usedPresets=Perfect:3
visiblePage=pluginsPage
visiblePlugin=equalizer#0

[Style]
forceBreezeTheme=false

[Window]
autostartOnLogin=true
height=512
visiblePipeWirePage=clientsPage
width=1912
      '';
    };

    "easyeffects/db/stereotoolsrc" = {
      force = true;
      text = ''
[soe][StereoTools#0]
balanceIn=0.08
      '';
    };

    "easyeffects/db/graphrc" = {
      force = true;
      text = ''
[Graph]
borderColors=255,255,255
colorScheme=automatic
colorTheme=qtGreen
      '';
    };
  };
}
