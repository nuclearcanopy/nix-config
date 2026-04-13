{ lib, ... }:

{
  # Desktop-only: avoid forcing GPU/VA-API paths that can cause video stutter.
  programs.firefox.profiles.default.settings = {
    "gfx.webrender.all" = lib.mkForce false;
    "layers.acceleration.force-enabled" = lib.mkForce false;
    "gfx.webrender.compositor.force-enabled" = lib.mkForce false;
    "media.ffmpeg.vaapi.enabled" = lib.mkForce false;
    "media.hardware-video-decoding.force-enabled" = lib.mkForce false;
  };
}
